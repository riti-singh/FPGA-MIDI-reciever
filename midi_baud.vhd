library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity midi_baud is
    generic (
        CLK_HZ  : integer := 100_000_000;   -- Basys3
        BAUD    : integer := 31_250
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        en       : in  std_logic;           -- enable ticks while in a frame
        clr      : in  std_logic;           -- restart timing from the current sample
        tick_half: out std_logic;           -- pulse at ~Tbit/2
        tick_bit : out std_logic            -- pulse every Tbit
    );
end entity;

architecture rtl of midi_baud is
    constant CYC_PER_BIT  : integer := CLK_HZ / BAUD;      -- 3200
    constant HALF_TARGET  : integer := CYC_PER_BIT/2;      -- 1600
    signal cnt            : integer range 0 to CYC_PER_BIT := 0;
    signal half_armed     : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' or en='0' or clr='1' then
                cnt        <= 0;
                half_armed <= '0';
                tick_half  <= '0';
                tick_bit   <= '0';
            else
                tick_half <= '0';
                tick_bit  <= '0';
                cnt <= cnt + 1;

                if (half_armed='0' and cnt = HALF_TARGET) then
                    tick_half <= '1';
                    half_armed <= '1';
                end if;

                if cnt = CYC_PER_BIT-1 then
                    tick_bit  <= '1';
                    cnt       <= 0;
                    half_armed<= '0';
                end if;
            end if;
        end if;
    end process;
end architecture;
