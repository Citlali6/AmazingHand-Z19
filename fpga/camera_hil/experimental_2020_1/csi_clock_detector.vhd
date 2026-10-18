-- Private structural replacement; original MIT notice is retained in source.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xpm;
use xpm.vcomponents.all;
entity csi_rx_clock_det is
  port(ref_clock, ext_clock, enable, reset_in : in std_logic;
       reset_out : out std_logic);
end csi_rx_clock_det;
architecture structural of csi_rx_clock_det is
  signal heartbeat : std_logic := '0';
  signal heartbeat_ref, heartbeat_last : std_logic := '0';
  signal missing_count : unsigned(7 downto 0) := (others => '1');
  signal missing_ref : std_logic := '1';
begin
  -- Real source-domain FF, not an unregistered clock net used as CDC data.
  process(ext_clock) begin
    if rising_edge(ext_clock) then heartbeat <= not heartbeat; end if;
  end process;
  heartbeat_sync : xpm_cdc_single
    generic map(DEST_SYNC_FF=>3, INIT_SYNC_FF=>1, SRC_INPUT_REG=>0, SIM_ASSERT_CHK=>0)
    port map(src_clk=>'0', src_in=>heartbeat, dest_clk=>ref_clock, dest_out=>heartbeat_ref);
  process(ref_clock) begin
    if rising_edge(ref_clock) then
      heartbeat_last <= heartbeat_ref;
      if reset_in='1' or enable='0' then
        missing_count <= (others=>'1'); missing_ref <= '1';
      elsif heartbeat_ref /= heartbeat_last then
        missing_count <= (others=>'0'); missing_ref <= '0';
      elsif missing_count < 200 then
        missing_count <= missing_count + 1;
      else
        missing_ref <= '1';
      end if;
    end if;
  end process;
  -- Missing clocks ASSERT reset even when byte clock has stopped high or low.
  -- Restoration releases only through three actual destination clock edges.
  reset_transfer : xpm_cdc_async_rst
    generic map(DEST_SYNC_FF=>3, INIT_SYNC_FF=>1, RST_ACTIVE_HIGH=>1)
    port map(src_arst=>missing_ref, dest_clk=>ext_clock, dest_arst=>reset_out);
end structural;
