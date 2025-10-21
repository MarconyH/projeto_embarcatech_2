-- lane.vhd
--
-- top level
--
-- FPGA Vision Remote Lab http://h-brs.de/fpga-vision-lab
-- (c) Marco Winzker, Hochschule Bonn-Rhein-Sieg, 03.01.2018

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity lane is
  port (clk       : in  std_logic;                      -- input clock 74.25 MHz, video 720p
        reset_n   : in  std_logic;                      -- reset (invoked during configuration)
        enable_in : in  std_logic_vector(2 downto 0);   -- three slide switches
        -- video in
        vs_in     : in  std_logic;                      -- vertical sync
        hs_in     : in  std_logic;                      -- horizontal sync
        de_in     : in  std_logic;                      -- data enable is '1' for valid pixel
        r_in      : in  std_logic_vector(7 downto 0);   -- red component of pixel
        g_in      : in  std_logic_vector(7 downto 0);   -- green component of pixel
        b_in      : in  std_logic_vector(7 downto 0);   -- blue component of pixel
        -- video out
        vs_out    : out std_logic;                      -- corresponding to video-in
        hs_out    : out std_logic;
        de_out    : out std_logic;
        r_out     : out std_logic_vector(7 downto 0);
        g_out     : out std_logic_vector(7 downto 0);
        b_out     : out std_logic_vector(7 downto 0);
        --
        clk_o     : out std_logic;                      -- output clock (do not modify)
        led       : out std_logic_vector(2 downto 0));  -- not supported by remote lab
end lane;

architecture behave of lane is

  -- input/output FFs
  signal reset              : std_logic;
  signal enable             : std_logic_vector(2 downto 0);
  signal rgb_in, rgb_out    : std_logic_vector(23 downto 0);
  signal rgb_sobel          : std_logic_vector(23 downto 0);
  signal vs_0, hs_0, de_0   : std_logic;
  signal vs_1, hs_1, de_1   : std_logic;
  signal vs_2, hs_2, de_2   : std_logic;
  
  -- Hough signals
  signal edge_detected      : std_logic;
  signal x_coord, y_coord   : integer range 0 to 1279;
  signal x_coord_sync, y_coord_sync : integer range 0 to 1279;  -- Sincronizado com edge_detected
  signal x_delayed, y_delayed : integer range 0 to 1279;
  signal hough_processing   : std_logic;
  signal line_detected      : std_logic;
  signal line_rho           : integer;
  signal line_theta         : integer;
  
  -- Pipeline de atraso para sincronizar coordenadas com Sobel
  type delay_array_t is array (0 to 13) of integer range 0 to 1279;
  signal x_delay_pipe : delay_array_t;
  signal y_delay_pipe : delay_array_t;
  
  -- Pipeline menor para sincronizar coordenadas com edge_detected (7 ciclos)
  type delay_edge_t is array (0 to 6) of integer range 0 to 1279;
  signal x_delay_for_edge : delay_edge_t;
  signal y_delay_for_edge : delay_edge_t;

begin

  process
  begin
    wait until rising_edge(clk);

    -- input FFs for control
    reset  <= not reset_n;
    enable <= enable_in;
    -- input FFs for video signal
    vs_0   <= vs_in;
    hs_0   <= hs_in;
    de_0   <= de_in;
    rgb_in <= r_in & g_in & b_in;
  end process;

  -- signal processing
  sobel : entity work.lane_sobel
    port map (clk           => clk,
              reset         => reset,
              de_in         => de_0,
              data_in       => rgb_in,
              data_out      => rgb_sobel,
              edge_detected => edge_detected);
  
  -- Hough Transform
  hough : entity work.lane_hough
    generic map (IMG_WIDTH  => 1280,
                 IMG_HEIGHT => 720)
    port map (clk           => clk,
              reset         => reset,
              vs_in         => vs_0,
              de_in         => de_0,
              edge_detected => edge_detected,
              x_coord       => x_coord_sync,  -- SINCRONIZADO com edge_detected
              y_coord       => y_coord_sync,  -- SINCRONIZADO com edge_detected
              processing    => hough_processing,
              line_detected => line_detected,
              line_rho      => line_rho,
              line_theta    => line_theta);

  -- delay control signals to match pipeline stages of signal processing
  control : entity work.lane_sync
    generic map (delay => 7)
    port map (clk    => clk,
              reset  => reset,
              vs_in  => vs_0,
              hs_in  => hs_0,
              de_in  => de_0,
              vs_out => vs_1,
              hs_out => hs_1,
              de_out => de_1);
              
  -- delay adicional para coordenadas
  control2 : entity work.lane_sync
    generic map (delay => 7)
    port map (clk    => clk,
              reset  => reset,
              vs_in  => vs_1,
              hs_in  => hs_1,
              de_in  => de_1,
              vs_out => vs_2,
              hs_out => hs_2,
              de_out => de_2);

  -- Contador de coordenadas de pixel para Hough Transform
  process
  begin
    wait until rising_edge(clk);
    
    if reset = '1' or vs_0 = '1' then
      x_coord <= 0;
      y_coord <= 0;
    elsif de_0 = '1' then
      if x_coord < 1279 then
        x_coord <= x_coord + 1;
      else
        x_coord <= 0;
        if y_coord < 719 then
          y_coord <= y_coord + 1;
        else
          y_coord <= 0;
        end if;
      end if;
    end if;
  end process;
  
  -- Atraso de 1 ciclo para sincronizar coordenadas com edge_detected do Sobel
  -- Sobel tem pipeline: 2 (shift) + linha + g_matrix + soma + ROM ≈ muitos ciclos
  -- Testando com atraso maior
  process
  begin
    wait until rising_edge(clk);
    -- Pipeline de múltiplos estágios para sincronizar com Sobel
    x_delay_for_edge(0) <= x_coord;
    y_delay_for_edge(0) <= y_coord;
    for i in 1 to 6 loop
      x_delay_for_edge(i) <= x_delay_for_edge(i-1);
      y_delay_for_edge(i) <= y_delay_for_edge(i-1);
    end loop;
    x_coord_sync <= x_delay_for_edge(6);  -- 7 ciclos de atraso
    y_coord_sync <= y_delay_for_edge(6);
  end process;
  
  -- Atraso das coordenadas para sincronizar com pipeline do Sobel (14 ciclos)
  -- Pipeline: lane_sync (7) + lane_sobel + lane_sync (7) = 14 ciclos
  process
  begin
    wait until rising_edge(clk);
    -- Shift register de 14 estágios
    x_delay_pipe(0) <= x_coord;
    y_delay_pipe(0) <= y_coord;
    for i in 1 to 13 loop
      x_delay_pipe(i) <= x_delay_pipe(i-1);
      y_delay_pipe(i) <= y_delay_pipe(i-1);
    end loop;
    x_delayed <= x_delay_pipe(13);
    y_delayed <= y_delay_pipe(13);
  end process;

  -- Overlay: desenhar linha verde sobre região com maior concentração de bordas
  process
    variable dist_to_line : integer;
    variable is_edge : std_logic;
  begin
    wait until rising_edge(clk);
    
    -- SIMPLIFICADO: line_rho agora é diretamente a posição X em pixels
    -- line_theta sempre = 2 (90°, linha vertical)
    
    -- Verifica se o pixel atual do Sobel é uma borda (escuro)
    is_edge := '0';
    if unsigned(rgb_sobel(7 downto 0)) < 128 then
      is_edge := '1';
    end if;
    
    if line_detected = '1' and de_1 = '1' then
      -- Calcular distância do pixel atual à linha vertical
      dist_to_line := abs(x_delayed - line_rho);
      
      -- Se pixel está próximo da linha (±30 pixels) E é uma borda, desenhar verde
      if dist_to_line < 30 and is_edge = '1' then
        rgb_out <= x"00FF00";  -- VERDE (00=R, FF=G, 00=B)
      else
        rgb_out <= rgb_sobel;  -- Sobel normal
      end if;
      
    else
      -- Sem linha detectada: mostrar apenas Sobel
      rgb_out <= rgb_sobel;
    end if;
  end process;

  process
  begin
    wait until rising_edge(clk);

    -- output FFs for video signal
    vs_out <= vs_2;
    hs_out <= hs_2;
    de_out <= de_2;
    if (de_2 = '1') then
      -- active video
      r_out <= rgb_out(23 downto 16);
      g_out <= rgb_out(15 downto 8);
      b_out <= rgb_out(7 downto 0);

    else
      -- blanking, set output to black
      r_out <= "00000000";
      g_out <= "00000000";
      b_out <= "00000000";

    end if;
  end process;

  -- do not modify
  clk_o <= clk;
  led   <= "000";

end behave;
