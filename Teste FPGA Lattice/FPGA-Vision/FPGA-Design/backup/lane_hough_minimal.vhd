-- lane_hough_minimal.vhd
--
-- Versão ULTRA-MINIMALISTA da Transformada de Hough
-- Sem acumulador - apenas detecção em tempo real
--
-- Esta versão NÃO usa BRAM para acumular votos.
-- Estratégia: Detectar linhas verticais dominantes em tempo real
-- analisando a concentração de bordas em colunas específicas.
--
-- RECURSOS: < 200 LABs (vs 2936 da versão lightweight!)

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity lane_hough is
  generic (
    IMG_WIDTH  : integer := 1280;
    IMG_HEIGHT : integer := 720;
    THETA_BINS : integer := 9;     -- Compatibilidade com lane.vhd
    RHO_BINS   : integer := 128    -- Compatibilidade com lane.vhd
  );
  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    -- Interface de entrada (pixel do Sobel)
    vs_in         : in  std_logic;
    de_in         : in  std_logic;
    edge_detected : in  std_logic;
    x_coord       : in  integer range 0 to IMG_WIDTH-1;
    y_coord       : in  integer range 0 to IMG_HEIGHT-1;
    -- Interface de saída
    processing    : out std_logic;
    line_detected : out std_logic;
    line_rho      : out integer;
    line_theta    : out integer
  );
end lane_hough;

architecture behave of lane_hough is

  -- Contadores simplificados para detecção de linha vertical
  type column_counter_t is array (0 to 15) of integer range 0 to 65535;
  signal column_votes : column_counter_t;  -- 16 colunas (1280/80 = 16)
  
  signal max_votes_col : integer range 0 to 15;
  signal max_votes_val : integer range 0 to 65535;
  
  signal frame_active : std_logic;
  signal vs_prev : std_logic;
  signal line_detected_reg : std_logic;
  
  constant VOTE_THRESHOLD : integer := 50;  -- Threshold ajustável

begin

  processing <= frame_active;
  line_detected <= line_detected_reg;
  
  -- Linha detectada: sempre vertical (theta = 2, que é 90°)
  line_theta <= 2;  
  
  -- Rho baseado na coluna com mais votos (mapear 0-15 para 0-127)
  line_rho <= max_votes_col * 8 + 64;  -- Aproximação: coluna × 8 + offset

  -- Processo unificado: detecção de frame + acumulação de votos
  process(clk)
    variable col_idx : integer range 0 to 15;
  begin
    if rising_edge(clk) then
      vs_prev <= vs_in;
      
      -- Detectar borda de subida de vs_in (início de frame)
      if vs_in = '1' and vs_prev = '0' then
        frame_active <= '1';
        
        -- Resetar contadores para novo frame
        for i in 0 to 15 loop
          column_votes(i) <= 0;
        end loop;
        max_votes_val <= 0;
        max_votes_col <= 0;
        
      elsif vs_in = '0' and vs_prev = '1' then
        -- Fim de frame: encontrar coluna com mais votos
        frame_active <= '0';
        
        max_votes_val <= 0;
        max_votes_col <= 0;
        for i in 0 to 15 loop
          if column_votes(i) > max_votes_val then
            max_votes_val <= column_votes(i);
            max_votes_col <= i;
          end if;
        end loop;
        
        -- Decidir se linha foi detectada
        if max_votes_val > VOTE_THRESHOLD then
          line_detected_reg <= '1';
        else
          line_detected_reg <= '0';
        end if;
        
      else
        -- Durante o frame: acumular votos em tempo real (streaming)
        if de_in = '1' and edge_detected = '1' and frame_active = '1' then
          -- Mapear coordenada X para coluna (1280 / 80 = 16 colunas)
          col_idx := x_coord / 80;
          
          -- Incrementar contador da coluna correspondente
          if col_idx < 16 then
            column_votes(col_idx) <= column_votes(col_idx) + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

end behave;
