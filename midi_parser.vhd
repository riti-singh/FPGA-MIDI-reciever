library ieee;
use ieee.std_logic_1164.all;

entity midi_parser is
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    byte_in        : in  std_logic_vector(7 downto 0);
    byte_valid     : in  std_logic;
    -- Outputs matching your diagram
    status_byte    : out std_logic_vector(7 downto 0); -- event/channel (0x9n / 0x8n, etc.)
    key            : out std_logic_vector(7 downto 0);
    velocity       : out std_logic_vector(7 downto 0);
    message_ready  : out std_logic;  -- pulse when 3 bytes captured
    note_on        : out std_logic;  -- pulse when status=1001xxxx
    note_off       : out std_logic   -- pulse when status=1000xxxx
  );
end entity;

architecture rtl of midi_parser is
  type s_t is (WAIT_STATUS, WAIT_KEY, WAIT_VEL);
  signal s   : s_t := WAIT_STATUS;
  signal st  : std_logic_vector(7 downto 0) := (others=>'0');
  signal ky  : std_logic_vector(7 downto 0) := (others=>'0');
  signal vel : std_logic_vector(7 downto 0) := (others=>'0');
begin
  status_byte <= st; key <= ky; velocity <= vel;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        s <= WAIT_STATUS; st <= (others=>'0'); ky <= (others=>'0'); vel <= (others=>'0');
        message_ready <= '0'; note_on <= '0'; note_off <= '0';
      else
        message_ready <= '0'; note_on <= '0'; note_off <= '0';
        if byte_valid='1' then
          case s is
            when WAIT_STATUS =>
              st <= byte_in;
              s  <= WAIT_KEY;

            when WAIT_KEY =>
              ky <= byte_in;
              s  <= WAIT_VEL;

            when WAIT_VEL =>
              vel <= byte_in;
              message_ready <= '1';
              if st(7 downto 4) = "1001" then note_on  <= '1'; end if;
              if st(7 downto 4) = "1000" then note_off <= '1'; end if;
              s <= WAIT_STATUS;
          end case;
        end if;
      end if;
    end if;
  end process;
end architecture;
