//-----------------------------------------------------------------------------
// pipeline_latency_timer.v
//-----------------------------------------------------------------------------
//
// Filename        : pipeline_latency_timer.v
// Version         : v1.0
// Description     : Global free-running 64-bit counter with multi-channel
//                   ordered timestamp capture with skip support. Triggers
//                   are captured in order (ch0, ch1, ..., chN-1). If the
//                   expected channel has not fired but a later channel fires,
//                   skipped channels are zero-filled and capture continues.
//                   Timestamps are promoted to AXI-readable registers only
//                   when the last channel completes the sequence, guaranteeing
//                   every readout is a complete, ordered set (0 = skipped).
// Verilog-Standard: Verilog-2001
//
//-----------------------------------------------------------------------------
// Register Map (AXI4-Lite, 32-bit words):
//
//   Offset  | Name          | Access | Description
//   --------|---------------|--------|-------------------------------------
//   0x000   | CTRL          | W      | [0]: soft-reset counter (self-clears)
//   0x004   | CNT_LSB       | R      | global_cnt[31:0]
//            |               |        | Reading CNT_LSB snapshots CNT_MSB
//   0x008   | CNT_MSB       | R      | global_cnt[63:32] (from snapshot)
//   0x00C   | TS_CH0_LSB    | R      | ts_capture[0][31:0]  (0 if skipped)
//   0x010   | TS_CH0_MSB    | R      | ts_capture[0][63:32] (0 if skipped)
//   0x014   | TS_CH1_LSB    | R      | ts_capture[1][31:0]  (0 if skipped)
//   0x018   | TS_CH1_MSB    | R      | ts_capture[1][63:32] (0 if skipped)
//    ...     |   ...         |        |   ...
//   0x00C + ch*8 + 0  : TS_CHch_LSB
//   0x00C + ch*8 + 4  : TS_CHch_MSB
//
// With default C_NUM_TS_CH=8, max offset = 0x050.
// Address space fits in 7 bits; 12-bit AXI addr port provided for flexibility.
//
//-----------------------------------------------------------------------------
// Usage:
//   1. Connect clk/rstn (same clock domain as the signals to be measured).
//   2. Connect each trig[ch] to the pipeline event signal (rising edge captured).
//   3. Connect global_cnt output to sibling modules that latch their own
//      timestamps internally (avoids routing trig signals back here).
//   4. Read timestamps via AXI4-Lite: read CNT_LSB first (snapshots MSB),
//      then CNT_MSB for atomic 64-bit counter read.
//-----------------------------------------------------------------------------

`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings="yes" *)
module pipeline_latency_timer #(
    parameter C_NUM_TS_CH    = 8,   // Number of timestamp capture channels
    parameter C_CLK_FREQ_MHZ = 200  // Clock frequency in MHz (documentation only)
)(
    // Clock and Reset (active-low reset)
    input  wire                     clk,
    input  wire                     rstn,

    // Timestamp trigger inputs - one per channel.
    // Timestamp is captured on the RISING EDGE of each trig[ch].
    input  wire [C_NUM_TS_CH-1:0]  trig,

    // Global counter output for use by sibling modules on the same clock.
    // Connect to modules that latch their own timestamps independently.
    output wire [63:0]              global_cnt,

    // AXI4-Lite Slave Interface
    // Write address channel
    input  wire [11:0]              s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output reg                      s_axi_awready,
    // Write data channel
    input  wire [31:0]              s_axi_wdata,
    input  wire [3:0]               s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output reg                      s_axi_wready,
    // Write response channel
    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,
    // Read address channel
    input  wire [11:0]              s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output reg                      s_axi_arready,
    // Read data channel
    output reg  [31:0]              s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready
);

// ---------------------------------------------------------------------------
// Local parameters
// ---------------------------------------------------------------------------
localparam ADDR_CTRL      = 12'h000;  // W   : bit[0] = soft-reset
localparam ADDR_CNT_LSB   = 12'h004;  // R   : counter[31:0]
localparam ADDR_CNT_MSB   = 12'h008;  // R   : counter[63:32]
// Channel n LSB: 12'h00C + n*8
// Channel n MSB: 12'h010 + n*8

localparam RESP_OKAY      = 2'b00;
localparam RESP_SLVERR    = 2'b10;

// ---------------------------------------------------------------------------
// 64-bit free-running counter
// ---------------------------------------------------------------------------
reg [63:0] cnt_r;
reg        soft_rst;   // self-clearing, one-cycle pulse

always @(posedge clk) begin
    if (~rstn || soft_rst) begin
        cnt_r <= 64'b0;
    end else begin
        cnt_r <= cnt_r + 64'd1;
    end
end

assign global_cnt = cnt_r;

// ---------------------------------------------------------------------------
// Trigger edge detection and ordered timestamp capture (with skip)
// ---------------------------------------------------------------------------
// Triggers are captured in order: ch0, ch1, ..., ch(N-1).
// If the expected channel has NOT fired but a LATER channel fires, the
// intermediate channels are marked as skipped (timestamp = 0) and capture
// continues from the later channel. When the last channel fires (or is
// reached via skip), all shadow values are promoted atomically to
// ts_capture[], which is what the AXI-Lite read path returns.
// Software sees 0 for skipped channels and valid timestamps for triggered
// channels, always in order.
// ---------------------------------------------------------------------------

reg  [C_NUM_TS_CH-1:0] trig_d;
reg  [63:0]             ts_capture [0:C_NUM_TS_CH-1]; // AXI-readable (stable)
reg  [63:0]             ts_shadow  [0:C_NUM_TS_CH-1]; // in-flight capture

// Width of the channel index counter
localparam CH_IDX_W = (C_NUM_TS_CH > 1) ? $clog2(C_NUM_TS_CH) : 1;
reg [CH_IDX_W:0] next_ch;  // one extra bit so we can represent C_NUM_TS_CH

integer ch;
integer k;

// Edge detection
always @(posedge clk) begin
    if (~rstn) begin
        trig_d <= {C_NUM_TS_CH{1'b0}};
    end else begin
        trig_d <= trig;
    end
end

// Rising-edge flags
wire [C_NUM_TS_CH-1:0] trig_rise;
genvar g;
generate
    for (g = 0; g < C_NUM_TS_CH; g = g + 1) begin : gen_rise
        assign trig_rise[g] = trig[g] & ~trig_d[g];
    end
endgenerate

// Combinational priority encoder: find lowest triggered channel >= next_ch
reg [CH_IDX_W:0] found_ch;
reg               found_valid;

always @(*) begin
    found_ch    = {(CH_IDX_W+1){1'b0}};
    found_valid = 1'b0;
    for (k = 0; k < C_NUM_TS_CH; k = k + 1) begin
        if (!found_valid && (k >= next_ch) && trig_rise[k]) begin
            found_ch    = k[CH_IDX_W:0];
            found_valid = 1'b1;
        end
    end
end

// Ordered capture state machine (with skip support)
always @(posedge clk) begin
    if (~rstn || soft_rst) begin
        next_ch <= {(CH_IDX_W+1){1'b0}};
        for (ch = 0; ch < C_NUM_TS_CH; ch = ch + 1) begin
            ts_capture[ch] <= 64'b0;
            ts_shadow[ch]  <= 64'b0;
        end
    end else if (found_valid) begin
        // Zero-fill skipped channels in shadow
        for (ch = 0; ch < C_NUM_TS_CH; ch = ch + 1) begin
            if (ch >= next_ch && ch < found_ch)
                ts_shadow[ch] <= 64'b0;
        end
        // Capture the found channel
        ts_shadow[found_ch] <= cnt_r;

        if (found_ch == C_NUM_TS_CH - 1) begin
            // Last channel reached: promote shadow -> capture atomically
            for (ch = 0; ch < C_NUM_TS_CH; ch = ch + 1) begin
                if (ch < next_ch)
                    ts_capture[ch] <= ts_shadow[ch];   // previously captured
                else if (ch < found_ch)
                    ts_capture[ch] <= 64'b0;           // skipped
                else // ch == found_ch == C_NUM_TS_CH-1
                    ts_capture[ch] <= cnt_r;            // current cycle
            end
            next_ch <= {(CH_IDX_W+1){1'b0}};           // restart sequence
        end else begin
            next_ch <= found_ch + 1'b1;
        end
    end
end

// ---------------------------------------------------------------------------
// AXI4-Lite Write Channel
// ---------------------------------------------------------------------------
// Accept write address and write data simultaneously (both channels together)
reg  [11:0] wr_addr_r;
reg  [31:0] wr_data_r;

// Write state: 0=idle, 1=wait for both aw+w, 2=send bresp
reg [1:0] wr_state;
localparam WR_IDLE  = 2'd0;
localparam WR_BRESP = 2'd1;

always @(posedge clk) begin
    if (~rstn) begin
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        s_axi_bvalid  <= 1'b0;
        s_axi_bresp   <= RESP_OKAY;
        soft_rst      <= 1'b0;
        wr_addr_r     <= 12'b0;
        wr_data_r     <= 32'b0;
        wr_state      <= WR_IDLE;
    end else begin
        soft_rst <= 1'b0;   // default: not asserted

        case (wr_state)
            WR_IDLE: begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                s_axi_bvalid  <= 1'b0;
                if (s_axi_awvalid && s_axi_wvalid) begin
                    // Capture address and data
                    wr_addr_r     <= s_axi_awaddr;
                    wr_data_r     <= s_axi_wdata;
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b1;
                    wr_state      <= WR_BRESP;
                end
            end

            WR_BRESP: begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;

                // Decode write target
                if (wr_addr_r == ADDR_CTRL) begin
                    if (wr_data_r[0]) begin
                        soft_rst <= 1'b1;   // reset counter
                    end
                    s_axi_bresp <= RESP_OKAY;
                end else begin
                    s_axi_bresp <= RESP_SLVERR; // all other addresses read-only
                end

                s_axi_bvalid <= 1'b1;

                if (s_axi_bvalid && s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    wr_state     <= WR_IDLE;
                end
            end

            default: wr_state <= WR_IDLE;
        endcase
    end
end

// ---------------------------------------------------------------------------
// AXI4-Lite Read Channel
// ---------------------------------------------------------------------------
// Snapshot MSB when LSB is read for atomic 64-bit access
reg [31:0] cnt_msb_snap;

reg [1:0] rd_state;
localparam RD_IDLE  = 2'd0;
localparam RD_DATA  = 2'd1;

always @(posedge clk) begin
    if (~rstn) begin
        s_axi_arready  <= 1'b0;
        s_axi_rvalid   <= 1'b0;
        s_axi_rdata    <= 32'b0;
        s_axi_rresp    <= RESP_OKAY;
        cnt_msb_snap   <= 32'b0;
        rd_state       <= RD_IDLE;
    end else begin
        case (rd_state)
            RD_IDLE: begin
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b0;
                if (s_axi_arvalid) begin
                    s_axi_arready <= 1'b1;
                    rd_state      <= RD_DATA;

                    // Decode read address and drive rdata
                    if (s_axi_araddr == ADDR_CNT_LSB) begin
                        // Snapshot MSB atomically with LSB read
                        s_axi_rdata  <= cnt_r[31:0];
                        cnt_msb_snap <= cnt_r[63:32];
                        s_axi_rresp  <= RESP_OKAY;
                    end else if (s_axi_araddr == ADDR_CNT_MSB) begin
                        s_axi_rdata  <= cnt_msb_snap;
                        s_axi_rresp  <= RESP_OKAY;
                    end else begin
                        // Check timestamp channel addresses
                        s_axi_rdata <= 32'hDEAD_BEEF;   // default: bad address
                        s_axi_rresp <= RESP_SLVERR;

                        // Use a for-loop to decode channel addresses.
                        // Synthesises to a priority mux.
                        begin : addr_decode
                            integer n;
                            for (n = 0; n < C_NUM_TS_CH; n = n + 1) begin
                                if (s_axi_araddr == (12'h00C + n * 8)) begin
                                    s_axi_rdata <= ts_capture[n][31:0];
                                    s_axi_rresp <= RESP_OKAY;
                                end else if (s_axi_araddr == (12'h010 + n * 8)) begin
                                    s_axi_rdata <= ts_capture[n][63:32];
                                    s_axi_rresp <= RESP_OKAY;
                                end
                            end
                        end
                    end
                end
            end

            RD_DATA: begin
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b1;
                if (s_axi_rvalid && s_axi_rready) begin
                    s_axi_rvalid <= 1'b0;
                    rd_state     <= RD_IDLE;
                end
            end

            default: rd_state <= RD_IDLE;
        endcase
    end
end

endmodule
