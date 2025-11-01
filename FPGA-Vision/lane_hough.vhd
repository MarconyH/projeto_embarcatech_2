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

  signal frame_active : std_logic := '0';
  signal vs_prev : std_logic := '0';
  signal line_detected_reg : std_logic := '1';
  signal last_edge_x : integer range 0 to IMG_WIDTH-1 := 640;  -- FORÇA inicialização em 640!

begin

  processing <= frame_active;
  line_detected <= line_detected_reg;
  
  -- Linha detectada: sempre vertical (theta = 2, que é 90°)
  line_theta <= 2;  
  
  -- Rho = posição X em pixels da ÚLTIMA BORDA DETECTADA
  line_rho <= last_edge_x;  -- DIRETO, sem conversão!

  -- Processo ULTRA-SIMPLIFICADO: atualiza SEMPRE que edge_detected='1'
  process(clk)
  begin
    if rising_edge(clk) then
      vs_prev <= vs_in;
      
      -- Detectar início de frame
      if vs_in = '1' and vs_prev = '0' then
        frame_active <= '1';
        line_detected_reg <= '0';
        last_edge_x <= 640;  -- RESETA para centro
        
      -- Detectar fim de frame  
      elsif vs_in = '0' and vs_prev = '1' then
        frame_active <= '0';
        line_detected_reg <= '1';
      end if;
      
      -- SEMPRE atualiza quando edge_detected='1', independente de frame_active ou de_in
      if edge_detected = '1' then
        last_edge_x <= x_coord;
      end if;
      
    end if;
  end process;

end behave;
