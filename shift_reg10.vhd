library ieee;
use ieee.std_logic_1164.all;

entity shift_reg10 is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    clr      : in  std_logic;
    shift_en : in  std_logic;              -- pulse at each bit center
    din      : in  std_logic;              -- sampled serial bit
    q        : out std_logic_vector(9 downto 0)
  );
end entity;

architecture rtl of shift_reg10 is
  signal r : std_logic_vector(9 downto 0) := (others=>'1'); -- idle '1'
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' or clr='1' then
        r <= (others=>'1');
      elsif shift_en='1' then
        r <= r(8 downto 0) & din;         -- shift toward MSB; new bit enters bit 0
      end if;
    end if;
  end process;
  q <= r;
end architecture;
