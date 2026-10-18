`timescale 1ns/1ps
// Private helpers use vendor XPM CDCs and their instance-scoped constraints.
module csi_application_gate(input wire byte_clk, input wire qualified,
                            output wire ready, output wire reset_byte);
  xpm_cdc_async_rst #(.DEST_SYNC_FF(3),.INIT_SYNC_FF(1),.RST_ACTIVE_HIGH(1))
    qualification_reset(.src_arst(!qualified),.dest_clk(byte_clk),.dest_arst(reset_byte));
  reg [6:0] count = 0;
  reg ready_q = 0;
  always @(posedge byte_clk) begin
    if(reset_byte) begin count<=0; ready_q<=0; end
    else if(count<64) begin count<=count+1; ready_q<=0; end
    else ready_q<=1;
  end
  // Immediate invalidation from the XPM async assertion, synchronous release.
  assign ready = ready_q && !reset_byte;
endmodule

module csi_fifo_gate(input wire byte_clk, stream_clk,
  input wire link_reset, stream_reset_n,
  input wire wr_busy, rd_busy, full, empty, source_valid, sink_ready,
  output wire fifo_reset, wr_en, rd_en, out_valid);
  // Reuse the actual byte-domain link reset: qualification, clock failure and
  // 64-cycle settling. Flush stale FIFO data after any link failure.
  // No second ref-to-byte reset synchronizer or independent release.
  assign fifo_reset = link_reset;
  reg write_ready = 0;
  always @(posedge byte_clk or posedge link_reset)
    if(link_reset) write_ready<=0;
    else write_ready <= !fifo_reset && !wr_busy;
  wire read_qualified;
  xpm_cdc_single #(.DEST_SYNC_FF(3),.INIT_SYNC_FF(1),.SRC_INPUT_REG(0))
    ready_transfer(.src_clk(1'b0),.src_in(write_ready),.dest_clk(stream_clk),.dest_out(read_qualified));
  assign wr_en = source_valid && write_ready && !wr_busy && !full;
  assign out_valid = stream_reset_n && read_qualified && !rd_busy && !empty;
  assign rd_en = sink_ready && out_valid;
endmodule
