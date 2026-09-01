library ieee;
use ieee.std_logic_1164.all;

entity sync_start is
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        rx_in  : in  std_logic;       -- from Pmod MIDI level shifter
        rx     : out std_logic;       -- synchronized
        start  : out std_logic        -- 1 clk pulse on high->low edge (start bit)
    );
end entity;

architecture rtl of sync_start is
    signal d1, d2, d2_prev : std_logic := '1';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                d1      <= '1';
                d2      <= '1';
                d2_prev <= '1';
            else
                d1      <= rx_in;
                d2      <= d1;
                d2_prev <= d2;
            end if;
        end if;
    end process;
    rx    <= d2;
    start <= '1' when (d2='0' and d2_prev='1') else '0';
end architecture;
