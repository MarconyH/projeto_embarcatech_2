-- lane_hough_lightweight.vhd
--
-- Transformada de Hough SIMPLIFICADA para detecção de linhas
-- Versão ultra-leve para FPGA com recursos limitados
--
-- OTIMIZAÇÕES:
-- - Apenas 9 ângulos (80°, 85°, 90°, 95°, 100°, 130°, 135°, 140°, 145°)
-- - Resolução de rho reduzida (divisão por 16)
-- - Acumulador de apenas 9 × 128 = 1,152 posições
-- - ~18 Kbit de BRAM vs 10+ Mbit da versão completa

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity lane_hough is
  generic (
    IMG_WIDTH  : integer := 1280;
    IMG_HEIGHT : integer := 720;
    THETA_BINS : integer := 9;     -- Apenas ângulos relevantes para pistas
    RHO_BINS   : integer := 128    -- Resolução reduzida (1808/16 ≈ 113)
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
    line_rho      : out integer;    -- parâmetro rho da linha (escalado)
    line_theta    : out integer     -- índice do ângulo (0-8)
  );
end lane_hough;

architecture behave of lane_hough is

  type state_t is (IDLE, ACCUMULATE, FIND_PEAKS, DONE);
  signal state : state_t;
  
  -- Acumulador reduzido (9 × 128 = 1,152 posições = ~18 Kbit)
  type accumulator_t is array (0 to RHO_BINS-1, 0 to THETA_BINS-1) of integer range 0 to 65535;
  signal accumulator : accumulator_t;
  
  -- LUTs para sin/cos APENAS dos ângulos relevantes (Q1.15 format)
  -- Ângulos: 80°, 85°, 90°, 95°, 100°, 130°, 135°, 140°, 145°
  type lut_t is array (0 to THETA_BINS-1) of signed(15 downto 0);
  
  -- Sin LUT para ângulos selecionados
  signal sin_lut : lut_t := (
    to_signed(32253, 16),  -- sin(80°)  ≈ 0.9848
    to_signed(32588, 16),  -- sin(85°)  ≈ 0.9962
    to_signed(32767, 16),  -- sin(90°)  = 1.0000
    to_signed(32588, 16),  -- sin(95°)  ≈ 0.9962
    to_signed(32253, 16),  -- sin(100°) ≈ 0.9848
    to_signed(25102, 16),  -- sin(130°) ≈ 0.7660
    to_signed(23170, 16),  -- sin(135°) ≈ 0.7071
    to_signed(21063, 16),  -- sin(140°) ≈ 0.6428
    to_signed(18795, 16)   -- sin(145°) ≈ 0.5736
  );
  
  -- Cos LUT para ângulos selecionados
  signal cos_lut : lut_t := (
    to_signed(5690, 16),    -- cos(80°)  ≈ 0.1736
    to_signed(2856, 16),    -- cos(85°)  ≈ 0.0872
    to_signed(0, 16),       -- cos(90°)  = 0.0000
    to_signed(-2856, 16),   -- cos(95°)  ≈ -0.0872
    to_signed(-5690, 16),   -- cos(100°) ≈ -0.1736
    to_signed(-21063, 16),  -- cos(130°) ≈ -0.6428
    to_signed(-23170, 16),  -- cos(135°) ≈ -0.7071
    to_signed(-25102, 16),  -- cos(140°) ≈ -0.7660
    to_signed(-26510, 16)   -- cos(145°) ≈ -0.8090
  );
  
  signal theta_idx : integer range 0 to THETA_BINS-1;
  signal rho_calc  : signed(31 downto 0);
  signal rho_idx   : integer range 0 to RHO_BINS-1;
  
  signal max_votes : integer range 0 to 65535;
  signal best_rho  : integer range 0 to RHO_BINS-1;
  signal best_theta: integer range 0 to THETA_BINS-1;
  
  signal frame_done : std_logic;
  signal vs_prev    : std_logic;

begin

  processing <= '1' when state /= IDLE and state /= DONE else '0';
  line_rho   <= best_rho;
  line_theta <= best_theta;
  line_detected <= '1' when max_votes > 30 else '0';  -- Threshold ajustável

  -- Detecção de início de frame
  process(clk)
  begin
    if rising_edge(clk) then
      vs_prev <= vs_in;
      if vs_in = '1' and vs_prev = '0' then
        frame_done <= '1';
      else
        frame_done <= '0';
      end if;
    end if;
  end process;

  -- Máquina de estados principal
  process(clk, reset)
    variable x_shifted : signed(31 downto 0);
    variable y_shifted : signed(31 downto 0);
    variable cos_val   : signed(15 downto 0);
    variable sin_val   : signed(15 downto 0);
    variable x_cos     : signed(47 downto 0);  -- 32 + 16 = 48 bits
    variable y_sin     : signed(47 downto 0);  -- 32 + 16 = 48 bits
    variable rho_temp  : signed(47 downto 0);  -- Resultado da soma
    variable rho_final : integer;
  begin
    if reset = '1' then
      state <= IDLE;
      theta_idx <= 0;
      max_votes <= 0;
      best_rho <= 0;
      best_theta <= 0;
      
      -- Limpar acumulador
      for r in 0 to RHO_BINS-1 loop
        for t in 0 to THETA_BINS-1 loop
          accumulator(r, t) <= 0;
        end loop;
      end loop;
      
    elsif rising_edge(clk) then
    
      case state is
      
        when IDLE =>
          if frame_done = '1' then
            -- Limpar acumulador para novo frame
            for r in 0 to RHO_BINS-1 loop
              for t in 0 to THETA_BINS-1 loop
                accumulator(r, t) <= 0;
              end loop;
            end loop;
            state <= ACCUMULATE;
            max_votes <= 0;
          end if;
        
        when ACCUMULATE =>
          if de_in = '1' and edge_detected = '1' then
            -- Para cada ângulo na LUT, calcular rho e acumular voto
            for t in 0 to THETA_BINS-1 loop
              -- rho = x*cos(theta) + y*sin(theta)
              -- Aritmética Q1.15: resultado em Q2.30, shift right 15 bits
              x_shifted := to_signed(x_coord, 32);
              y_shifted := to_signed(y_coord, 32);
              cos_val := cos_lut(t);
              sin_val := sin_lut(t);
              
              -- Multiplicação (32-bit × 16-bit = 48-bit)
              x_cos := x_shifted * cos_val;
              y_sin := y_shifted * sin_val;
              rho_temp := x_cos + y_sin;  -- 48-bit soma
              
              -- Shift para converter Q2.30 → Q17.15, depois dividir por 16
              rho_temp := shift_right(rho_temp, 15);  -- Q2.30 → Q17.15
              rho_temp := shift_right(rho_temp, 4);   -- Dividir por 16 para reduzir bins
              
              -- Converter para índice com offset
              rho_final := to_integer(rho_temp(31 downto 0)) + (RHO_BINS / 2);
              
              -- Garantir que está dentro dos limites
              if rho_final >= 0 and rho_final < RHO_BINS then
                accumulator(rho_final, t) <= accumulator(rho_final, t) + 1;
              end if;
            end loop;
          end if;
          
          -- Quando frame termina, buscar picos
          if vs_in = '1' then
            state <= FIND_PEAKS;
          end if;
        
        when FIND_PEAKS =>
          -- Buscar máximo no acumulador
          max_votes <= 0;
          for r in 0 to RHO_BINS-1 loop
            for t in 0 to THETA_BINS-1 loop
              if accumulator(r, t) > max_votes then
                max_votes <= accumulator(r, t);
                best_rho <= r;
                best_theta <= t;
              end if;
            end loop;
          end loop;
          state <= DONE;
        
        when DONE =>
          -- Esperar próximo frame
          if frame_done = '1' then
            state <= IDLE;
          end if;
      
      end case;
    end if;
  end process;

end behave;
