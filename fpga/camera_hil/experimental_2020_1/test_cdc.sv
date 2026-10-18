`timescale 1ns/1ps
module test_cdc;
  reg refclk=0, byteclk=0, streamclk=0;
  reg run_byte=1, reset=1, qualified=0, wr_busy=1, rd_busy=1;
  reg source_valid=0, sink_ready=0, full=0, empty=1, stream_reset_n=1;
  wire detector_reset, app_ready, app_reset, fifo_reset, wen, ren, valid;
  always #2.491 refclk=~refclk;
  always #5 streamclk=~streamclk;
  always begin #11.636; if(run_byte) byteclk=~byteclk; end
  csi_rx_clock_det detector(.ref_clock(refclk),.ext_clock(byteclk),.enable(1'b1),.reset_in(reset),.reset_out(detector_reset));
  csi_application_gate app(.byte_clk(byteclk),.qualified(qualified),.ready(app_ready),.reset_byte(app_reset));
  csi_fifo_gate gate(.byte_clk(byteclk),.stream_clk(streamclk),.link_reset(detector_reset|app_reset|!app_ready),.wr_busy(wr_busy),.rd_busy(rd_busy),
    .full(full),.empty(empty),.stream_reset_n(stream_reset_n),.source_valid(source_valid),.sink_ready(sink_ready),
    .fifo_reset(fifo_reset),.wr_en(wen),.rd_en(ren),.out_valid(valid));
  task cycles(input integer count); repeat(count) @(posedge byteclk); #1; endtask
  task check_safe;
    if(wen || ren || valid) $fatal(1,"unsafe FIFO transfer while reset/busy/unready");
  endtask
  initial begin
    #200; reset=0;
    cycles(10);
    if(app_ready || !fifo_reset) $fatal(1,"RDY delay did not keep application/FIFO reset");
    qualified=1;
    cycles(65);
    if(app_ready) $fatal(1,"application released before sync+64 clocks");
    cycles(7);
    if(!app_ready || detector_reset) $fatal(1,"application/detector did not acquire");
    source_valid=1; sink_ready=1; empty=0;
    cycles(5); check_safe();
    wr_busy=0;
    cycles(8);
    if(!wen || valid || ren) $fatal(1,"write qualification/read busy behavior");
    rd_busy=0; repeat(6) @(posedge streamclk); #1;
    if(!valid || !ren) $fatal(1,"read ready propagation");
    full=1; #1; if(wen) $fatal(1,"full write"); full=0;
    empty=1; #1; if(ren||valid) $fatal(1,"empty read"); empty=0;
    sink_ready=0; #1; if(!valid || ren) $fatal(1,"AXIS valid must not depend on ready");
    sink_ready=1;
    stream_reset_n=0; #1; if(valid || ren) $fatal(1,"stream reset did not gate transfer");
    stream_reset_n=1;
    @(negedge byteclk); run_byte=0;
    #1500;
    if(!detector_reset || !fifo_reset) $fatal(1,"stopped LOW clock did not detect and flush FIFO");
    repeat(6) @(posedge streamclk); #1;
    if(valid||ren) $fatal(1,"stopped clock did not invalidate read qualifier");
    run_byte=1; cycles(12);
    if(detector_reset) $fatal(1,"clock restart did not release synchronously");
    @(posedge byteclk); #1; run_byte=0;
    #1500;
    if(!detector_reset || !fifo_reset) $fatal(1,"stopped HIGH clock did not detect and flush FIFO");
    run_byte=1; cycles(12);
    if(detector_reset) $fatal(1,"second clock restart failed");
    qualified=0; #1;
    if(app_ready || !fifo_reset) $fatal(1,"RDY loss did not assert asynchronously");
    qualified=1; cycles(72);
    if(!app_ready) $fatal(1,"requalification failed");
    reset=1; #30;
    if(!detector_reset) $fatal(1,"reference reset did not propagate");
    $display("PASS_CDC power_reset RDY_delay clock_stop_low_high restart FIFO_busy_full_empty valid_backpressure requalification");
    $finish;
  end
  initial begin #30000; $fatal(1,"CDC test timeout"); end
endmodule
