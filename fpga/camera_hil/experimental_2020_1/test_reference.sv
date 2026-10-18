`timescale 1ns/1fs
// Focused vendor-primitive simulation of the NEW clock/reset sequencer only.
// Does not simulate the external sensor or assert hardware calibration success.
module test_reference;
  reg clk = 0, reset = 1;
  reg [3:0] ready = 0;
  wire refclk, io_reset, delay_reset, all_ready;
  csi_delay_reference dut(.clk_pl0(clk), .reset(reset),
    .ready0(ready[0]), .ready1(ready[1]), .ready2(ready[2]), .ready3(ready[3]),
    .refclk(refclk), .io_reset(io_reset), .delay_reset(delay_reset), .all_ready(all_ready));
  always #2.491231115596 clk = !clk;
  real io_release, controller_release, edge1, edge2;
  initial begin
    #200 reset = 0;
    @(negedge io_reset); io_release = $realtime;
    if (!dut.locked || !delay_reset) $fatal(1, "IO released before lock/CTRL reset");
    @(negedge delay_reset); controller_release = $realtime;
    if (controller_release - io_release < 106.0) $fatal(1, "CTRL reset released too early");
    @(posedge refclk); edge1 = $realtime;
    @(posedge refclk); edge2 = $realtime;
    if (edge2-edge1 < 3.319 || edge2-edge1 > 3.325) $fatal(1, "Reference is not physical 301.056MHz");
    ready = 4'b0111;
    repeat (10) @(posedge refclk);
    if (all_ready) $fatal(1, "Ignored missing controller RDY");
    ready = 4'b1111;
    repeat (5) @(posedge refclk);
    #0.01;
    if (!all_ready) $fatal(1, "Four ready controllers did not release");
    for (integer i=0; i<4; i=i+1) begin
      ready[i] = 0; repeat(5) @(posedge refclk); #0.01;
      if (all_ready) $fatal(1, "RDY loss did not clear registered qualification");
      ready[i] = 1;
      repeat (5) @(posedge refclk);
    end
    force dut.locked = 0;
    #0.01;
    if (!io_reset || !delay_reset || all_ready) $fatal(1, "Lock-loss assertion failed");
    release dut.locked;
    wait(!io_reset && !delay_reset);
    repeat(6) @(posedge refclk); #0.01;
    if(!all_ready) $fatal(1,"MMCM relock/requalification failed");
    reset = 1; #0.01;
    if (!io_reset || !delay_reset || all_ready) $fatal(1, "Reset assertion failed");
    $display("PASS_REFERENCE physical_period_ns=%0.9f io_to_ctrl_ns=%0.3f all_four_RDY_required no_sensor_clock_dependency", edge2-edge1, controller_release-io_release);
    $finish;
  end
  initial begin #20000; $fatal(1, "Reference sequencer timeout"); end
endmodule
