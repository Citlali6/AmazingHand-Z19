//-----------------------------------------------------------------------------
// frame_event_counter.v
//-----------------------------------------------------------------------------
//
// Filename        : frame_event_counter.v
// Version         : v1.0
// Description     : Frame event counter with timestamp capture. Counts rising
//                   edges of a composite trigger signal and latches the global
//                   timer value at each event. The trigger input can be driven
//                   by a single signal or by an external AND of multiple
//                   signals — the module simply detects the rising edge.
//
//                   Outputs frame_num and frame_ts are updated synchronously
//                   on each trigger event and remain stable until the next.
//
// Verilog-Standard: Verilog-2001
//
//-----------------------------------------------------------------------------
// Port summary:
//
//   clk         : clock (same domain as global_cnt source)
//   rstn        : active-low synchronous reset
//   trig        : trigger input (rising edge detected)
//   global_cnt  : 64-bit free-running counter from pipeline_latency_timer
//   frame_num   : 32-bit frame counter (0 after reset, +1 per trigger)
//   frame_ts    : 64-bit timestamp latched at the most recent trigger edge
//   frame_pulse : single-cycle pulse on each trigger edge (for daisy-chain)
//
//-----------------------------------------------------------------------------

`timescale 1ps/1ps

module frame_event_counter #(
    parameter C_NUM_TS_CH    = 8   // Number of trigger input signals
)(
    input  wire        clk,
    input  wire        rstn,

    // Trigger inputs — all signals are ANDed internally.
    // Rising edge of the AND result increments frame_num and latches timestamp.
    input  wire [C_NUM_TS_CH-1:0] trig,

    // Global free-running counter from pipeline_latency_timer
    input  wire [63:0] global_cnt,

    // Outputs
    output reg  [31:0] frame_num,    // current frame number
    output reg  [63:0] frame_ts,     // timestamp of latest trigger
    output reg         frame_pulse   // single-cycle pulse on trigger edge
);

// ---------------------------------------------------------------------------
// Internal AND of all trigger inputs, then rising-edge detection
// ---------------------------------------------------------------------------
wire trig_and = &trig;   // all bits ANDed

reg trig_and_d;

always @(posedge clk) begin
    if (~rstn)
        trig_and_d <= 1'b0;
    else
        trig_and_d <= trig_and;
end

wire trig_rise = trig_and & ~trig_and_d;

// ---------------------------------------------------------------------------
// Frame counter and timestamp latch
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (~rstn) begin
        frame_num   <= 32'd0;
        frame_ts    <= 64'd0;
        frame_pulse <= 1'b0;
    end else begin
        frame_pulse <= 1'b0;           // default: no pulse

        if (trig_rise) begin
            frame_num   <= frame_num + 32'd1;
            frame_ts    <= global_cnt;
            frame_pulse <= 1'b1;
        end
    end
end

endmodule
