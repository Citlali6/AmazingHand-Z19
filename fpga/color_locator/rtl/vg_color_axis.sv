// SPDX-License-Identifier: MIT
// Reuses the pinned, unmodified laperex RGB->HSV core. See vendor/laperex/ORIGIN.md.
// Accepted pixels reserve a FIFO slot BEFORE entering the free-running core.
// This is required: the upstream core has no clock-enable/backpressure input.
module vg_color_axis #(
    parameter integer FIFO_DEPTH = 16
) (
    input  wire         aclk,
    input  wire         aresetn,
    // All configuration is synchronous to aclk and sampled on an accepted SOF.
    // 0=disabled, 1=red, 2=green, 3=blue. Not a speech recognition interface.
    input  wire [1:0]   cfg_color,
    input  wire [7:0]   cfg_min_s,
    input  wire [7:0]   cfg_min_v,
    // 0x00RRGGBB, one pixel per accepted beat. tuser=SOF, tlast=end of line.
    input  wire [31:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tuser,
    input  wire         s_axis_tlast,
    // bit31=selected-color mask; bits30:24=0; bits23:0=original RGB.
    output wire [31:0]  m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,
    output wire         m_axis_tuser,
    output wire         m_axis_tlast
);
    // FIFO_DEPTH must be a power of two, >=8. The verified build uses depth16.
    localparam integer PTR_W = $clog2(FIFO_DEPTH);
    localparam integer COUNT_W = $clog2(FIFO_DEPTH + 1);
    localparam integer CORE_LATENCY = 6;
    reg [33:0] fifo [0:FIFO_DEPTH-1];
    reg [PTR_W-1:0] wr_ptr, rd_ptr;
    reg [COUNT_W-1:0] fifo_count, outstanding;
    wire output_take = m_axis_tvalid && m_axis_tready;
    assign s_axis_tready = aresetn && ((outstanding < FIFO_DEPTH) || output_take);
    wire input_take = s_axis_tvalid && s_axis_tready;
    assign m_axis_tvalid = aresetn && fifo_count != 0;
    assign {m_axis_tuser, m_axis_tlast, m_axis_tdata} = fifo[rd_ptr];

    reg frame_enabled;
    reg [1:0] frame_color;
    reg [7:0] frame_min_s, frame_min_v;
    reg [23:0] rgb_delay [0:CORE_LATENCY-1];
    reg sof_delay [0:CORE_LATENCY-1];
    reg enabled_delay [0:CORE_LATENCY-1];
    reg [1:0] color_delay [0:CORE_LATENCY-1];
    reg [7:0] min_s_delay [0:CORE_LATENCY-1];
    reg [7:0] min_v_delay [0:CORE_LATENCY-1];
    cv_pkt_pkg::pkt_hsv hsv;
    wire hsv_valid, hsv_last;
    cv_rgb_to_hsv rgb_to_hsv (
        .aclk(aclk), .aresetn(aresetn), .in(s_axis_tdata[23:0]),
        .s_tvalid(input_take), .s_tlast(s_axis_tlast && input_take),
        .out(hsv), .m_tvalid(hsv_valid), .m_tlast(hsv_last)
    );
    reg hue_match;
    always @* begin
        case (color_delay[CORE_LATENCY-1])
            2'd1: hue_match = hsv.h <= 10 || (hsv.h >= 170 && hsv.h <= 179);
            2'd2: hue_match = hsv.h >= 35 && hsv.h <= 85;
            2'd3: hue_match = hsv.h >= 95 && hsv.h <= 135;
            default: hue_match = 1'b0;
        endcase
    end
    wire mask = enabled_delay[CORE_LATENCY-1] && hue_match &&
                hsv.s >= min_s_delay[CORE_LATENCY-1] &&
                hsv.v >= min_v_delay[CORE_LATENCY-1];

    integer i;
    always @(posedge aclk) begin
        if (!aresetn) begin
            wr_ptr <= 0; rd_ptr <= 0; fifo_count <= 0; outstanding <= 0;
            frame_enabled <= 0; frame_color <= 0; frame_min_s <= 0; frame_min_v <= 0;
            for (i=0; i<CORE_LATENCY; i=i+1) begin
                rgb_delay[i] <= 0; sof_delay[i] <= 0; enabled_delay[i] <= 0;
                color_delay[i] <= 0; min_s_delay[i] <= 0; min_v_delay[i] <= 0;
            end
        end else begin
            case ({input_take, output_take})
                2'b10: outstanding <= outstanding + 1'b1;
                2'b01: outstanding <= outstanding - 1'b1;
                default: ;
            endcase
            case ({hsv_valid, output_take})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: ;
            endcase
            if (input_take && s_axis_tuser) begin
                frame_enabled <= 1;
                frame_color <= cfg_color;
                frame_min_s <= cfg_min_s;
                frame_min_v <= cfg_min_v;
            end
            // Even during bubbles the arithmetic pipeline advances. Tags must too.
            rgb_delay[0] <= s_axis_tdata[23:0];
            sof_delay[0] <= s_axis_tuser && input_take;
            enabled_delay[0] <= frame_enabled || (input_take && s_axis_tuser);
            color_delay[0] <= input_take && s_axis_tuser ? cfg_color : frame_color;
            min_s_delay[0] <= input_take && s_axis_tuser ? cfg_min_s : frame_min_s;
            min_v_delay[0] <= input_take && s_axis_tuser ? cfg_min_v : frame_min_v;
            for (i=1; i<CORE_LATENCY; i=i+1) begin
                rgb_delay[i] <= rgb_delay[i-1]; sof_delay[i] <= sof_delay[i-1];
                enabled_delay[i] <= enabled_delay[i-1]; color_delay[i] <= color_delay[i-1];
                min_s_delay[i] <= min_s_delay[i-1]; min_v_delay[i] <= min_v_delay[i-1];
            end
            if (hsv_valid) begin
                fifo[wr_ptr] <= {sof_delay[CORE_LATENCY-1], hsv_last,
                                mask, 7'b0, rgb_delay[CORE_LATENCY-1]};
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (output_take) rd_ptr <= rd_ptr + 1'b1;
        end
    end
endmodule
