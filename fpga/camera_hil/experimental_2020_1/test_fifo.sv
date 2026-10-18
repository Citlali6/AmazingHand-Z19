`timescale 1ns/1ps
// Actual vendor FIFO, original 4096x42 auto/FWFT profile and default SIM_ASSERT_CHK=0.
// Independent transfer/overflow checks below; diagnostic assert=1 log is retained separately.
module test_fifo;
  reg byteclk=0, streamclk=0, run_byte=1, link_reset=1;
  reg source_valid=0, sink_ready=0, stream_reset_n=1;
  reg [41:0] din=42'h111;
  wire [41:0] dout;
  wire rst,wen,ren,valid,full,empty,wr_busy,rd_busy,overflow,underflow;
  always begin #11.636; if(run_byte) byteclk=~byteclk; end
  always #2.491 streamclk=~streamclk;
  csi_fifo_gate gate(.byte_clk(byteclk),.stream_clk(streamclk),.link_reset(link_reset),
    .stream_reset_n(stream_reset_n),.wr_busy(wr_busy),.rd_busy(rd_busy),.full(full),.empty(empty),
    .source_valid(source_valid),.sink_ready(sink_ready),.fifo_reset(rst),.wr_en(wen),.rd_en(ren),.out_valid(valid));
  xpm_fifo_async #(.CDC_SYNC_STAGES(2),.DOUT_RESET_VALUE("0"),.ECC_MODE("no_ecc"),
    .FIFO_MEMORY_TYPE("auto"),.FIFO_READ_LATENCY(0),.FIFO_WRITE_DEPTH(4096),
    .FULL_RESET_VALUE(0),.PROG_EMPTY_THRESH(10),.PROG_FULL_THRESH(10),
    .RD_DATA_COUNT_WIDTH(13),.READ_DATA_WIDTH(42),.READ_MODE("fwft"),
    .RELATED_CLOCKS(0),.SIM_ASSERT_CHK(0),.USE_ADV_FEATURES("0707"),
    .WAKEUP_TIME(0),.WRITE_DATA_WIDTH(42),.WR_DATA_COUNT_WIDTH(13)) fifo(
    .rst(rst),.wr_clk(byteclk),.rd_clk(streamclk),.din(din),.dout(dout),.wr_en(wen),.rd_en(ren),
    .full(full),.empty(empty),.wr_rst_busy(wr_busy),.rd_rst_busy(rd_busy),
    .sleep(1'b0),.injectsbiterr(1'b0),.injectdbiterr(1'b0),
    .almost_empty(),.almost_full(),.data_valid(),.dbiterr(),.overflow(overflow),.prog_empty(),
    .prog_full(),.rd_data_count(),.sbiterr(),.underflow(underflow),.wr_ack(),.wr_data_count());
  always @(posedge byteclk) if(wen && (wr_busy||full||rst)) $fatal(1,"unsafe vendor FIFO write");
  always @(posedge streamclk) if(ren && (rd_busy||empty||!stream_reset_n)) $fatal(1,"unsafe vendor FIFO read");
  always @(posedge byteclk) if(overflow===1'b1) $fatal(1,"vendor FIFO overflow");
  always @(posedge streamclk) if(underflow===1'b1) $fatal(1,"vendor FIFO underflow");
  integer got=0;
  always @(posedge streamclk) if(ren) begin
    if(dout!=42'h222) $fatal(1,"stale FIFO data after link loss: %h",dout);
    got<=got+1;
  end
  initial begin
    #500; link_reset=0; $display("FIFO_INIT_RELEASE");wait(!wr_busy&&!rd_busy);$display("FIFO_INIT_READY"); repeat(8) @(posedge byteclk);
    @(negedge byteclk);source_valid=1; repeat(4) @(posedge byteclk);
    @(negedge byteclk);source_valid=0; repeat(10) @(posedge streamclk);
    if(empty || !valid) $fatal(1,"initial stale payload not queued");
    @(negedge byteclk);run_byte=0;link_reset=1;
    repeat(12) @(posedge streamclk); if(valid||ren||wen) $fatal(1,"transfer during stopped-clock reset");
    // Keep reset asserted over restarted write-clock edges, matching link qualification.
    run_byte=1;repeat(10) @(posedge byteclk);@(negedge byteclk);link_reset=0;
    $display("FIFO_RESTART_RELEASE");wait(!wr_busy&&!rd_busy);$display("FIFO_RESTART_READY"); repeat(10) @(posedge byteclk);repeat(10) @(posedge streamclk);
    if(!empty || valid) $fatal(1,"FIFO did not flush stale payload");
    @(negedge byteclk);din=42'h222;source_valid=1;repeat(4) @(posedge byteclk);
    @(negedge byteclk);source_valid=0;repeat(10) @(posedge streamclk);
    if(!valid) $fatal(1,"new FIFO payload missing");
    stream_reset_n=0;#1;if(valid||ren) $fatal(1,"stream reset permits output");
    stream_reset_n=1;sink_ready=1;wait(got==4);repeat(10) @(posedge streamclk);
    if(!empty || valid) $fatal(1,"FIFO drain failed");
    $display("PASS_VENDOR_FIFO reset_busy flush_stale_on_clock_stop resume_new_data stream_reset backpressure");$finish;
  end
  initial begin #50000;$fatal(1,"FIFO test timeout busy=%b/%b empty=%b valid=%b got=%d",wr_busy,rd_busy,empty,valid,got);end
endmodule
