library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity midi_uart_rx is
  generic (
    CLK_HZ : integer := 100_000_000;
    BAUD   : integer := 31_250
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    rx_in      : in  std_logic;
    byte_data  : out std_logic_vector(7 downto 0);
    byte_valid : out std_logic
  );
end entity;

architecture rtl of midi_uart_rx is
  -- sync + start detect
  signal rx_sync, start_edge : std_logic;

  -- baud generator control
  signal baud_en, baud_clr   : std_logic;
  signal tick_half, tick_bit : std_logic;

  -- shift register + counter
  signal sr_q     : std_logic_vector(9 downto 0);
  signal cnt_tc   : std_logic;
  signal cnt_clr  : std_logic;
  signal sr_clr   : std_logic;
  signal shift_en : std_logic;

  type s_t is (IDLE, WAIT_HALF, SHIFTING, DONE);
  signal s : s_t := IDLE;
begin
  -- synchronizer + falling-edge start detector
  u_sync: entity work.sync_start
    port map (clk=>clk, rst=>rst, rx_in=>rx_in, rx=>rx_sync, start=>start_edge);

  -- baud generator (with clear)
  u_baud: entity work.midi_baud
    generic map (CLK_HZ=>CLK_HZ, BAUD=>BAUD)
    port map (clk=>clk, rst=>rst, en=>baud_en, clr=>baud_clr,
              tick_half=>tick_half, tick_bit=>tick_bit);

  -- counter: count 10 samples
  u_cnt: entity work.bit_counter10
    port map (clk=>clk, rst=>rst, clr=>cnt_clr, inc=>shift_en, tc10=>cnt_tc);

  -- 10-bit shift register; newest sample enters bit 0
  u_sr: entity work.shift_reg10
    port map (clk=>clk, rst=>rst, clr=>sr_clr, shift_en=>shift_en,
              din=>rx_sync, q=>sr_q);

  -- FSM
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        s         <= IDLE;
        baud_en   <= '0';
        baud_clr  <= '0';
        shift_en  <= '0';
        cnt_clr   <= '1';
        sr_clr    <= '1';
        byte_valid<= '0';
      else
        -- defaults
        baud_clr  <= '0';
        shift_en  <= '0';
        byte_valid<= '0';
        cnt_clr   <= '0';
        sr_clr    <= '0';

        case s is
          when IDLE =>
            baud_en <= '0';
            if start_edge='1' then
              baud_en <= '1';
              cnt_clr <= '1';
              sr_clr  <= '1';
              s       <= WAIT_HALF;
            end if;

          when WAIT_HALF =>
            if tick_half='1' then
              shift_en <= '1';      -- sample START center
              baud_clr <= '1';      -- force baud counter reset
              s        <= SHIFTING; -- next tick_bit = D0 center
            end if;

          when SHIFTING =>
            if tick_bit='1' then
              shift_en <= '1';      -- sample each data/stop center
            end if;
            if cnt_tc='1' then
              s <= DONE;
            end if;

          when DONE =>
            baud_en    <= '0';
            byte_valid <= '1';
            s          <= IDLE;
        end case;
      end if;
    end if;
  end process;

  -- Samples are stored as: stop, d7, ..., d0, start in q(0)..q(9).
  byte_data <= sr_q(1) & sr_q(2) & sr_q(3) & sr_q(4) &
               sr_q(5) & sr_q(6) & sr_q(7) & sr_q(8);
end architecture;
