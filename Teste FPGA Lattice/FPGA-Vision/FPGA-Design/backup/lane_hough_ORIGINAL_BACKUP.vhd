-- lane_hough.vhd
--
-- Hough Transform para detecção de linhas
-- Versão otimizada para FPGA usando aritmética de ponto fixo Q1.15
--
-- Baseado no algoritmo implementado em lane_fixed.c

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity lane_hough is
  generic (
    IMG_WIDTH  : integer := 1280;
    IMG_HEIGHT : integer := 720;
    THETA_BINS : integer := 180;
    RHO_BINS   : integer := 1808  -- sqrt(1280^2 + 720^2) * 2
  );
  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    -- Interface de entrada (pixel do Sobel)
    vs_in         : in  std_logic;  -- vertical sync (início de frame)
    de_in         : in  std_logic;  -- data enable
    edge_detected : in  std_logic;  -- '1' se pixel é borda (do Sobel)
    x_coord       : in  integer range 0 to IMG_WIDTH-1;
    y_coord       : in  integer range 0 to IMG_HEIGHT-1;
    -- Interface de saída
    processing    : out std_logic;  -- '1' durante processamento
    line_detected : out std_logic;  -- '1' quando linha detectada
    line_rho      : out integer;    -- parâmetro rho da linha
    line_theta    : out integer     -- parâmetro theta da linha
  );
end lane_hough;

architecture behave of lane_hough is

  type state_t is (IDLE, ACCUMULATE, FIND_PEAKS, DONE);
  signal state : state_t;
  
  -- Acumulador (usar BRAM)
  type accumulator_t is array (0 to RHO_BINS-1, 0 to THETA_BINS-1) of integer range 0 to 65535;
  signal accumulator : accumulator_t;
  
  -- LUTs para sin/cos em formato Q1.15 (pré-calculados)
  type lut_t is array (0 to THETA_BINS-1) of signed(15 downto 0);
  
  -- Sin LUT (valores Q1.15: sin(θ) * 32767)
  signal sin_lut : lut_t := (
    -- θ = 0 a 179 graus
    to_signed(0, 16), to_signed(572, 16), to_signed(1144, 16), to_signed(1715, 16),
    to_signed(2286, 16), to_signed(2856, 16), to_signed(3425, 16), to_signed(3993, 16),
    to_signed(4560, 16), to_signed(5126, 16), to_signed(5690, 16), to_signed(6252, 16),
    to_signed(6813, 16), to_signed(7371, 16), to_signed(7927, 16), to_signed(8481, 16),
    to_signed(9032, 16), to_signed(9580, 16), to_signed(10126, 16), to_signed(10668, 16),
    to_signed(11207, 16), to_signed(11743, 16), to_signed(12275, 16), to_signed(12803, 16),
    to_signed(13328, 16), to_signed(13848, 16), to_signed(14365, 16), to_signed(14876, 16),
    to_signed(15384, 16), to_signed(15886, 16), to_signed(16384, 16), to_signed(16877, 16),
    to_signed(17364, 16), to_signed(17847, 16), to_signed(18324, 16), to_signed(18795, 16),
    to_signed(19261, 16), to_signed(19720, 16), to_signed(20174, 16), to_signed(20622, 16),
    to_signed(21063, 16), to_signed(21498, 16), to_signed(21926, 16), to_signed(22348, 16),
    to_signed(22763, 16), to_signed(23170, 16), to_signed(23571, 16), to_signed(23965, 16),
    to_signed(24351, 16), to_signed(24730, 16), to_signed(25102, 16), to_signed(25466, 16),
    to_signed(25822, 16), to_signed(26170, 16), to_signed(26510, 16), to_signed(26842, 16),
    to_signed(27166, 16), to_signed(27482, 16), to_signed(27789, 16), to_signed(28088, 16),
    to_signed(28378, 16), to_signed(28660, 16), to_signed(28932, 16), to_signed(29197, 16),
    to_signed(29452, 16), to_signed(29698, 16), to_signed(29935, 16), to_signed(30163, 16),
    to_signed(30382, 16), to_signed(30591, 16), to_signed(30792, 16), to_signed(30982, 16),
    to_signed(31164, 16), to_signed(31336, 16), to_signed(31499, 16), to_signed(31651, 16),
    to_signed(31795, 16), to_signed(31928, 16), to_signed(32052, 16), to_signed(32166, 16),
    to_signed(32270, 16), to_signed(32365, 16), to_signed(32449, 16), to_signed(32524, 16),
    to_signed(32588, 16), to_signed(32643, 16), to_signed(32688, 16), to_signed(32723, 16),
    to_signed(32748, 16), to_signed(32763, 16), to_signed(32767, 16),  -- 90 graus
    to_signed(32763, 16), to_signed(32748, 16), to_signed(32723, 16), to_signed(32688, 16),
    to_signed(32643, 16), to_signed(32588, 16), to_signed(32524, 16), to_signed(32449, 16),
    to_signed(32365, 16), to_signed(32270, 16), to_signed(32166, 16), to_signed(32052, 16),
    to_signed(31928, 16), to_signed(31795, 16), to_signed(31651, 16), to_signed(31499, 16),
    to_signed(31336, 16), to_signed(31164, 16), to_signed(30982, 16), to_signed(30792, 16),
    to_signed(30591, 16), to_signed(30382, 16), to_signed(30163, 16), to_signed(29935, 16),
    to_signed(29698, 16), to_signed(29452, 16), to_signed(29197, 16), to_signed(28932, 16),
    to_signed(28660, 16), to_signed(28378, 16), to_signed(28088, 16), to_signed(27789, 16),
    to_signed(27482, 16), to_signed(27166, 16), to_signed(26842, 16), to_signed(26510, 16),
    to_signed(26170, 16), to_signed(25822, 16), to_signed(25466, 16), to_signed(25102, 16),
    to_signed(24730, 16), to_signed(24351, 16), to_signed(23965, 16), to_signed(23571, 16),
    to_signed(23170, 16), to_signed(22763, 16), to_signed(22348, 16), to_signed(21926, 16),
    to_signed(21498, 16), to_signed(21063, 16), to_signed(20622, 16), to_signed(20174, 16),
    to_signed(19720, 16), to_signed(19261, 16), to_signed(18795, 16), to_signed(18324, 16),
    to_signed(17847, 16), to_signed(17364, 16), to_signed(16877, 16), to_signed(16384, 16),
    to_signed(15886, 16), to_signed(15384, 16), to_signed(14876, 16), to_signed(14365, 16),
    to_signed(13848, 16), to_signed(13328, 16), to_signed(12803, 16), to_signed(12275, 16),
    to_signed(11743, 16), to_signed(11207, 16), to_signed(10668, 16), to_signed(10126, 16),
    to_signed(9580, 16), to_signed(9032, 16), to_signed(8481, 16), to_signed(7927, 16),
    to_signed(7371, 16), to_signed(6813, 16), to_signed(6252, 16), to_signed(5690, 16),
    to_signed(5126, 16), to_signed(4560, 16), to_signed(3993, 16), to_signed(3425, 16),
    to_signed(2856, 16), to_signed(2286, 16), to_signed(1715, 16), to_signed(1144, 16),
    to_signed(572, 16)  -- 179 graus (último ângulo)
  );
  
  -- Cos LUT (valores Q1.15: cos(θ) * 32767)
  signal cos_lut : lut_t := (
    -- cos(θ) = sin(θ + 90°)
    to_signed(32767, 16), to_signed(32763, 16), to_signed(32748, 16), to_signed(32723, 16),
    to_signed(32688, 16), to_signed(32643, 16), to_signed(32588, 16), to_signed(32524, 16),
    to_signed(32449, 16), to_signed(32365, 16), to_signed(32270, 16), to_signed(32166, 16),
    to_signed(32052, 16), to_signed(31928, 16), to_signed(31795, 16), to_signed(31651, 16),
    to_signed(31499, 16), to_signed(31336, 16), to_signed(31164, 16), to_signed(30982, 16),
    to_signed(30792, 16), to_signed(30591, 16), to_signed(30382, 16), to_signed(30163, 16),
    to_signed(29935, 16), to_signed(29698, 16), to_signed(29452, 16), to_signed(29197, 16),
    to_signed(28932, 16), to_signed(28660, 16), to_signed(28378, 16), to_signed(28088, 16),
    to_signed(27789, 16), to_signed(27482, 16), to_signed(27166, 16), to_signed(26842, 16),
    to_signed(26510, 16), to_signed(26170, 16), to_signed(25822, 16), to_signed(25466, 16),
    to_signed(25102, 16), to_signed(24730, 16), to_signed(24351, 16), to_signed(23965, 16),
    to_signed(23571, 16), to_signed(23170, 16), to_signed(22763, 16), to_signed(22348, 16),
    to_signed(21926, 16), to_signed(21498, 16), to_signed(21063, 16), to_signed(20622, 16),
    to_signed(20174, 16), to_signed(19720, 16), to_signed(19261, 16), to_signed(18795, 16),
    to_signed(18324, 16), to_signed(17847, 16), to_signed(17364, 16), to_signed(16877, 16),
    to_signed(16384, 16), to_signed(15886, 16), to_signed(15384, 16), to_signed(14876, 16),
    to_signed(14365, 16), to_signed(13848, 16), to_signed(13328, 16), to_signed(12803, 16),
    to_signed(12275, 16), to_signed(11743, 16), to_signed(11207, 16), to_signed(10668, 16),
    to_signed(10126, 16), to_signed(9580, 16), to_signed(9032, 16), to_signed(8481, 16),
    to_signed(7927, 16), to_signed(7371, 16), to_signed(6813, 16), to_signed(6252, 16),
    to_signed(5690, 16), to_signed(5126, 16), to_signed(4560, 16), to_signed(3993, 16),
    to_signed(3425, 16), to_signed(2856, 16), to_signed(2286, 16), to_signed(1715, 16),
    to_signed(1144, 16), to_signed(572, 16), to_signed(0, 16),  -- 90 graus
    to_signed(-572, 16), to_signed(-1144, 16), to_signed(-1715, 16), to_signed(-2286, 16),
    to_signed(-2856, 16), to_signed(-3425, 16), to_signed(-3993, 16), to_signed(-4560, 16),
    to_signed(-5126, 16), to_signed(-5690, 16), to_signed(-6252, 16), to_signed(-6813, 16),
    to_signed(-7371, 16), to_signed(-7927, 16), to_signed(-8481, 16), to_signed(-9032, 16),
    to_signed(-9580, 16), to_signed(-10126, 16), to_signed(-10668, 16), to_signed(-11207, 16),
    to_signed(-11743, 16), to_signed(-12275, 16), to_signed(-12803, 16), to_signed(-13328, 16),
    to_signed(-13848, 16), to_signed(-14365, 16), to_signed(-14876, 16), to_signed(-15384, 16),
    to_signed(-15886, 16), to_signed(-16384, 16), to_signed(-16877, 16), to_signed(-17364, 16),
    to_signed(-17847, 16), to_signed(-18324, 16), to_signed(-18795, 16), to_signed(-19261, 16),
    to_signed(-19720, 16), to_signed(-20174, 16), to_signed(-20622, 16), to_signed(-21063, 16),
    to_signed(-21498, 16), to_signed(-21926, 16), to_signed(-22348, 16), to_signed(-22763, 16),
    to_signed(-23170, 16), to_signed(-23571, 16), to_signed(-23965, 16), to_signed(-24351, 16),
    to_signed(-24730, 16), to_signed(-25102, 16), to_signed(-25466, 16), to_signed(-25822, 16),
    to_signed(-26170, 16), to_signed(-26510, 16), to_signed(-26842, 16), to_signed(-27166, 16),
    to_signed(-27482, 16), to_signed(-27789, 16), to_signed(-28088, 16), to_signed(-28378, 16),
    to_signed(-28660, 16), to_signed(-28932, 16), to_signed(-29197, 16), to_signed(-29452, 16),
    to_signed(-29698, 16), to_signed(-29935, 16), to_signed(-30163, 16), to_signed(-30382, 16),
    to_signed(-30591, 16), to_signed(-30792, 16), to_signed(-30982, 16), to_signed(-31164, 16),
    to_signed(-31336, 16), to_signed(-31499, 16), to_signed(-31651, 16), to_signed(-31795, 16),
    to_signed(-31928, 16), to_signed(-32052, 16), to_signed(-32166, 16), to_signed(-32270, 16),
    to_signed(-32365, 16), to_signed(-32449, 16), to_signed(-32524, 16), to_signed(-32588, 16),
    to_signed(-32643, 16), to_signed(-32688, 16), to_signed(-32723, 16), to_signed(-32748, 16),
    to_signed(-32763, 16)  -- 179 graus (último ângulo)
  );
  
  signal theta_idx : integer range 0 to THETA_BINS-1;
  signal rho_calc  : signed(31 downto 0);
  signal rho_idx   : integer range 0 to RHO_BINS-1;
  
  signal max_votes : integer range 0 to 65535;
  signal max_rho   : integer range 0 to RHO_BINS-1;
  signal max_theta : integer range 0 to THETA_BINS-1;

begin

  process(clk, reset)
    variable x_signed, y_signed : signed(15 downto 0);
    variable rho_temp : signed(31 downto 0);
  begin
    if reset = '1' then
      state <= IDLE;
      processing <= '0';
      line_detected <= '0';
      theta_idx <= 0;
      max_votes <= 0;
      
    elsif rising_edge(clk) then
    
      case state is
        when IDLE =>
          processing <= '0';
          line_detected <= '0';
          
          if vs_in = '1' then
            -- Novo frame: limpar acumulador
            for r in 0 to RHO_BINS-1 loop
              for t in 0 to THETA_BINS-1 loop
                accumulator(r, t) <= 0;
              end loop;
            end loop;
            state <= ACCUMULATE;
            processing <= '1';
          end if;
          
        when ACCUMULATE =>
          if de_in = '1' and edge_detected = '1' then
            -- Pixel é borda: votar em todos os ângulos
            x_signed := to_signed(x_coord, 16);
            y_signed := to_signed(y_coord, 16);
            
            -- Calcular rho para este theta
            -- rho = x*cos(theta) + y*sin(theta) em Q1.15
            rho_temp := (x_signed * cos_lut(theta_idx)) + (y_signed * sin_lut(theta_idx));
            -- Converter de Q1.15 para inteiro: dividir por 32768
            rho_calc <= shift_right(rho_temp, 15);
            
            -- Normalizar rho para índice do array (0 a RHO_BINS-1)
            rho_idx <= to_integer(rho_calc) + (RHO_BINS / 2);
            
            if rho_idx >= 0 and rho_idx < RHO_BINS then
              accumulator(rho_idx, theta_idx) <= accumulator(rho_idx, theta_idx) + 1;
            end if;
            
            -- Próximo theta
            if theta_idx < THETA_BINS-1 then
              theta_idx <= theta_idx + 1;
            else
              theta_idx <= 0;
            end if;
          end if;
          
          -- Terminou frame: buscar picos
          if vs_in = '0' and de_in = '0' then
            state <= FIND_PEAKS;
            theta_idx <= 0;
            max_votes <= 0;
          end if;
          
        when FIND_PEAKS =>
          -- Buscar máximo no acumulador
          for r in 0 to RHO_BINS-1 loop
            if accumulator(r, theta_idx) > max_votes then
              max_votes <= accumulator(r, theta_idx);
              max_rho <= r;
              max_theta <= theta_idx;
            end if;
          end loop;
          
          if theta_idx < THETA_BINS-1 then
            theta_idx <= theta_idx + 1;
          else
            state <= DONE;
          end if;
          
        when DONE =>
          -- Linha detectada se houver votos suficientes
          if max_votes > 50 then  -- Threshold ajustável
            line_detected <= '1';
            line_rho <= max_rho - (RHO_BINS / 2);  -- Desnormalizar
            line_theta <= max_theta;
          end if;
          
          processing <= '0';
          state <= IDLE;
          
      end case;
    end if;
  end process;

end behave;
