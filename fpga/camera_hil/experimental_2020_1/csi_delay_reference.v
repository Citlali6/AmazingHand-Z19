`timescale 1ns/1ps
// Experimental ZU19EG-only delay reference. PS/AXI/stream clocks stay unchanged.
// DS925: UltraScale+ IDELAYCTRL REFCLK 300..800 MHz, reset >=52 ns.
// Actual preserved PL0 200.703980 MHz * 6 / 4 = 301.055970 MHz.
// MMCM VCO=1204.223880 MHz; DS925 -2 MMCM VCO range 800..1600 MHz.
module csi_delay_reference(input wire clk_pl0, input wire reset,
                           input wire ready0, ready1, ready2, ready3,
                           output wire refclk, output wire io_reset,
                           output wire delay_reset, output wire all_ready);
  wire feedback_raw, feedback, ref_raw, locked;
  MMCME4_BASE #(.CLKIN1_PERIOD(4.982462231192426),
    .CLKFBOUT_MULT_F(6.0), .DIVCLK_DIVIDE(1), .CLKOUT0_DIVIDE_F(4.0),
    .BANDWIDTH("OPTIMIZED"), .STARTUP_WAIT("FALSE")) ref_mmcm (
    .CLKIN1(clk_pl0), .CLKFBIN(feedback), .CLKFBOUT(feedback_raw),
    .CLKOUT0(ref_raw), .LOCKED(locked), .RST(reset), .PWRDWN(1'b0),
    .CLKFBOUTB(), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(),
    .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6());
  BUFG feedback_buf(.I(feedback_raw), .O(feedback));
  BUFG reference_buf(.I(ref_raw), .O(refclk));
  // Immediate assertion on reset/lock loss; three-stage synchronous release.
  (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) reg [2:0] lock_release = 0;
  reg [39:0] reset_hold = 40'hffffffffff;
  always @(posedge refclk or posedge reset or negedge locked)
    if (reset || !locked) lock_release <= 0;
    else lock_release <= {lock_release[1:0], 1'b1};
  always @(posedge refclk or posedge reset or negedge locked)
    if (reset || !locked) reset_hold <= 40'hffffffffff;
    else if (!lock_release[2]) reset_hold <= 40'hffffffffff;
    else reset_hold <= {reset_hold[38:0], 1'b0};
  // Shared across ALL CSI instances/banks; no dependency on sensor clocks.
  // IO primitives release after 8 reference cycles; CTRL 32 cycles later.
  assign io_reset = reset_hold[7];
  assign delay_reset = reset_hold[39];
  wire [3:0] ready_ref;
  xpm_cdc_single #(.DEST_SYNC_FF(3),.INIT_SYNC_FF(1),.SRC_INPUT_REG(0))
    rdy0_sync(.src_clk(1'b0),.src_in(ready0),.dest_clk(refclk),.dest_out(ready_ref[0]));
  xpm_cdc_single #(.DEST_SYNC_FF(3),.INIT_SYNC_FF(1),.SRC_INPUT_REG(0))
    rdy1_sync(.src_clk(1'b0),.src_in(ready1),.dest_clk(refclk),.dest_out(ready_ref[1]));
  xpm_cdc_single #(.DEST_SYNC_FF(3),.INIT_SYNC_FF(1),.SRC_INPUT_REG(0))
    rdy2_sync(.src_clk(1'b0),.src_in(ready2),.dest_clk(refclk),.dest_out(ready_ref[2]));
  xpm_cdc_single #(.DEST_SYNC_FF(3),.INIT_SYNC_FF(1),.SRC_INPUT_REG(0))
    rdy3_sync(.src_clk(1'b0),.src_in(ready3),.dest_clk(refclk),.dest_out(ready_ref[3]));
  reg qualified_ref = 0;
  always @(posedge refclk or posedge io_reset)
    if(io_reset) qualified_ref<=0;
    else qualified_ref<= &ready_ref && !delay_reset;
  assign all_ready = qualified_ref;
endmodule
