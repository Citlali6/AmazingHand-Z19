`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/23 11:23:07
// Design Name: 
// Module Name: frame_ptr_trigger
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
/*
 * frame_ptr_trigger.v - 帧指针变化检测模块
 * 
 * 功能：检测 s2mm_frame_ptr_out 变化，产生可配置宽度的脉冲
 * 用于 VDMA 帧完成触发
 */

module frame_ptr_trigger #(
    parameter PULSE_WIDTH = 4,          // 脉冲宽度（时钟周期数）
    parameter PTR_WIDTH   = 6           // 帧指针宽度
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [PTR_WIDTH-1:0]  frame_ptr_in,    // s2mm_frame_ptr_out
    output reg                   frame_done_pulse, // 帧完成脉冲输出
    output reg  [PTR_WIDTH-1:0]  frame_ptr_out
);

    // 寄存上一拍的帧指针值
    reg [PTR_WIDTH-1:0] frame_ptr_d1;
    
    // 脉冲计数器
    reg [$clog2(PULSE_WIDTH+1)-1:0] pulse_cnt;
    
    // 变化检测
    wire ptr_changed;
    assign ptr_changed = (frame_ptr_in != frame_ptr_d1);

    // 寄存帧指针
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_ptr_d1 <= {PTR_WIDTH{1'b0}};
        end else begin
            frame_ptr_d1 <= frame_ptr_in;
        end
    end

    // 脉冲生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse_cnt <= 0;
            frame_done_pulse <= 1'b0;
        end else begin
            if (ptr_changed) begin
                // 检测到变化，开始产生脉冲
                pulse_cnt <= PULSE_WIDTH - 1;
                frame_done_pulse <= 1'b1;
            end else if (pulse_cnt > 0) begin
                // 脉冲计数
                pulse_cnt <= pulse_cnt - 1;
                frame_done_pulse <= 1'b1;
            end else begin
                // 脉冲结束
                frame_done_pulse <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        frame_ptr_out <= frame_ptr_in;
    end

endmodule
