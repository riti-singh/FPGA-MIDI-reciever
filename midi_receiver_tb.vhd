-- Minimal, clear testbench for midi_receiver
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity midi_receiver_tb is end entity;

architecture tb of midi_receiver_tb is
  constant CLK_HZ     : integer := 100_000_000;
  constant CLK_PERIOD : time    := 10 ns;      -- 100 MHz
  constant BIT_TIME   : time    := 32 us;      -- 1/31250 s

  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal rx_line      : std_logic := '1';      -- idle high

  signal status_b     : std_logic_vector(7 downto 0);
  signal key_b        : std_logic_vector(7 downto 0);
  signal vel_b        : std_logic_vector(7 downto 0);
  signal msg_rdy      : std_logic;
  signal note_on_p    : std_logic;
  signal note_off_p   : std_logic;
  signal messages_seen : natural := 0;

  -- Send a UART byte LSB-first with start/stop
  procedure send_byte(
    signal line : out std_logic;
    constant b  : in  std_logic_vector(7 downto 0)
  ) is
  begin
    line <= '0';                      -- start
    wait for BIT_TIME;
    for i in 0 to 7 loop              -- data bits LSB first
      line <= b(i);
      wait for BIT_TIME;
    end loop;
    line <= '1';                      -- stop
    wait for BIT_TIME;
    wait for BIT_TIME;                -- small idle
  end procedure;

begin
  -- 100 MHz clock
  clk <= not clk after CLK_PERIOD/2;

  -- DUT
  dut: entity work.midi_receiver
    generic map (CLK_HZ => CLK_HZ)
    port map (
      clk=>clk, rst=>rst, serial_in=>rx_line,
      event_channel=>status_b, key=>key_b, velocity=>vel_b,
      message_ready=>msg_rdy, note_on=>note_on_p, note_off=>note_off_p
    );

  -- Stimulus
  process
  begin
    rst <= '1'; wait for 200 ns; rst <= '0'; wait for 200 ns;

    -- NOTE ON: 0x90 (Note On ch0), key 0x3C (60), vel 0x40
    send_byte(rx_line, x"90");
    send_byte(rx_line, x"3C");
    send_byte(rx_line, x"40");
    wait for 3 ms;

    -- NOTE OFF: 0x80, same key, vel 0x00
    send_byte(rx_line, x"80");
    send_byte(rx_line, x"3C");
    send_byte(rx_line, x"00");
    wait for 1 ms;

    assert messages_seen=2 report "Expected two decoded MIDI messages" severity error;
    report "All MIDI receiver checks passed." severity note;
    std.env.stop;
    wait;
  end process;

  -- Console trace (helpful)
  process(clk)
  begin
    if rising_edge(clk) then
      if msg_rdy='1' then
        case messages_seen is
          when 0 =>
            assert status_b=x"90" and key_b=x"3C" and vel_b=x"40"
              report "NOTE ON message was decoded incorrectly" severity error;
            assert note_on_p='1' and note_off_p='0'
              report "NOTE ON classification pulse was incorrect" severity error;
          when 1 =>
            assert status_b=x"80" and key_b=x"3C" and vel_b=x"00"
              report "NOTE OFF message was decoded incorrectly" severity error;
            assert note_on_p='0' and note_off_p='1'
              report "NOTE OFF classification pulse was incorrect" severity error;
          when others =>
            assert false report "Unexpected extra MIDI message" severity error;
        end case;
        messages_seen <= messages_seen + 1;
        report "MSG: status=" & integer'image(to_integer(unsigned(status_b))) &
               " key=" & integer'image(to_integer(unsigned(key_b))) &
               " vel=" & integer'image(to_integer(unsigned(vel_b)));
      end if;
      if note_on_p='1'  then report "NOTE ON  key=" & integer'image(to_integer(unsigned(key_b))); end if;
      if note_off_p='1' then report "NOTE OFF key=" & integer'image(to_integer(unsigned(key_b))); end if;
    end if;
  end process;
end architecture;
