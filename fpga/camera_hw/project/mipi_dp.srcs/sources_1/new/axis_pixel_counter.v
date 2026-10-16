`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/31 12:07:38
// Design Name: 
// Module Name: axis_pixel_counter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// ============================================================
// AXI-Stream Pixel Counter + Frame Rate Monitor
// 用于验证 MIPI CSI-2 摄像头输出分辨率及帧率
//
// 接口说明:
//   - 标准 AXI-Stream Slave 接口 (tvalid/tready/tdata/tuser/tlast)
//   - tuser: 帧起始标志 (SOF, Start of Frame)
//   - tlast: 行结束标志 (EOL, End of Line)
//
// 帧率测量原理:
//   连续两帧 SOF 之间的时钟周期数 = frame_period
//   fps = CLK_FREQ_HZ / frame_period
//   为避免浮点, 输出 fps_x100 = CLK_FREQ_HZ * 100 / frame_period
//   示例: CLK_FREQ_HZ=100_000_000, frame_period=3_333_333
//         fps_x100 = 3000 → 实际帧率 30.00 fps
//
// ILA 读取方法:
//   fps_x100 = {fps_x100_hi, fps_x100_lo}
//   实际帧率 = fps_x100 / 100
// ============================================================

module axis_pixel_counter #(
    parameter DATA_WIDTH    = 40,          // tdata 位宽, RAW10 4-lane=40bit
    parameter CNT_WIDTH     = 16,          // 分辨率/行列计数器位宽
    parameter FRAME_WIDTH   = 16,          // 帧计数器位宽
    parameter CLK_FREQ_HZ   = 100_000_000  // 工作时钟频率 Hz
)(
    input  wire                   aclk,
    input  wire                   aresetn,       // 低有效复位

    // AXI-Stream Slave (并联监听, 不插入流水线)
    input  wire                   s_axis_tvalid,
    input  wire                   s_axis_tready,
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tuser,  // SOF
    input  wire                   s_axis_tlast,  // EOL

    // ---- 分辨率统计 ----
    output reg  [CNT_WIDTH-1:0]   col_cnt,
    output reg  [CNT_WIDTH-1:0]   row_cnt,
    output reg  [CNT_WIDTH-1:0]   width_latch,
    output reg  [CNT_WIDTH-1:0]   height_latch,

    // ---- 帧率统计 (32-bit 拆高低16, 方便 ILA probe 配置) ----
    //   frame_period = 相邻 SOF 间隔时钟数
    //   fps_x100     = 帧率 × 100 (整数), 读出后 ÷100 得实际 fps
    output reg  [CNT_WIDTH-1:0]   frame_period_lo,
    output reg  [CNT_WIDTH-1:0]   frame_period_hi,

    // ---- 调试计数 ----
    output reg  [CNT_WIDTH-1:0]   pixel_cnt_lo,
    output reg  [CNT_WIDTH-1:0]   pixel_cnt_hi,
    output reg  [FRAME_WIDTH-1:0] frame_cnt,

    // ---- 脉冲 (ILA trigger 用) ----
    output wire                   sof_pulse,
    output wire                   eol_pulse,
    output wire                   eof_pulse
);

    // ----------------------------------------------------------
    // 握手 & 脉冲
    // ----------------------------------------------------------
    wire handshake = s_axis_tvalid & s_axis_tready;
    assign sof_pulse = handshake & s_axis_tuser;
    assign eol_pulse = handshake & s_axis_tlast;
    assign eof_pulse = sof_pulse;

    // ----------------------------------------------------------
    // 列计数器
    // ----------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn)
            col_cnt <= 0;
        else if (handshake) begin
            if (s_axis_tuser || s_axis_tlast)
                col_cnt <= 0;
            else
                col_cnt <= col_cnt + 1'b1;
        end
    end

    // 行宽锁存
    always @(posedge aclk) begin
        if (!aresetn)
            width_latch <= 0;
        else if (eol_pulse)
            width_latch <= col_cnt + 1'b1;
    end

    // ----------------------------------------------------------
    // 行计数器
    // ----------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn)
            row_cnt <= 0;
        else if (handshake) begin
            if (s_axis_tuser)
                row_cnt <= 0;
            else if (s_axis_tlast)
                row_cnt <= row_cnt + 1'b1;
        end
    end

    // 帧高锁存
    always @(posedge aclk) begin
        if (!aresetn)
            height_latch <= 0;
        else if (sof_pulse)
            height_latch <= row_cnt + 1'b1;
    end

    // ----------------------------------------------------------
    // 帧计数器
    // ----------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn)
            frame_cnt <= 0;
        else if (sof_pulse)
            frame_cnt <= frame_cnt + 1'b1;
    end

    // ----------------------------------------------------------
    // 帧内像素总数
    // ----------------------------------------------------------
    reg [31:0] pixel_cnt_r;
    always @(posedge aclk) begin
        if (!aresetn)
            pixel_cnt_r <= 0;
        else if (sof_pulse)
            pixel_cnt_r <= 0;
        else if (handshake && !s_axis_tuser)
            pixel_cnt_r <= pixel_cnt_r + 1'b1;
    end
    always @(posedge aclk) begin
        pixel_cnt_lo <= pixel_cnt_r[15:0];
        pixel_cnt_hi <= pixel_cnt_r[31:16];
    end

    // ----------------------------------------------------------
    // 帧率测量
    //
    // 步骤:
    //   1. free_cnt: 自由运行 32-bit 计数器, 全程递增
    //   2. 每帧 SOF 时打时间戳, 与上一帧时间戳作差 → frame_period
    //   3. 用移位试商除法计算 fps_x100 = CLK*100 / frame_period
    //      除法器 32 个时钟周期完成, 结果在下一帧开始前已稳定
    // ----------------------------------------------------------

    // 自由运行计数器
    reg [31:0] free_cnt;
    always @(posedge aclk) begin
        if (!aresetn) free_cnt <= 0;
        else          free_cnt <= free_cnt + 1'b1;
    end

    // 帧周期测量
    reg [31:0] sof_ts;          // 上一帧 SOF 时间戳
    reg [31:0] frame_period_r;
    reg        fp_valid;        // 第一帧后置1, 此后 frame_period_r 有效

    always @(posedge aclk) begin
        if (!aresetn) begin
            sof_ts         <= 0;
            frame_period_r <= 0;
            fp_valid       <= 0;
        end else if (sof_pulse) begin
            sof_ts   <= free_cnt;
            fp_valid <= 1'b1;
            if (fp_valid)
                frame_period_r <= free_cnt - sof_ts;
        end
    end

    always @(posedge aclk) begin
        frame_period_lo <= frame_period_r[15:0];
        frame_period_hi <= frame_period_r[31:16];
    end

endmodule