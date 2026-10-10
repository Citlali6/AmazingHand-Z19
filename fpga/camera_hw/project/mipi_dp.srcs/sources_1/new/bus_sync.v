`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 16:34:28
// Design Name: 
// Module Name: bus_sync
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

// 简单的 8 位同步器
module bus_sync (
    input  wire       dest_clk, // 接 ILA 的时钟
    input  wire [7:0] async_in, // 接 Concat 的输出
    output reg  [7:0] sync_out  // 接 ILA 和你的计时器模块
);
    (* ASYNC_REG = "TRUE" *) reg [7:0] sync_reg_1, sync_reg_2;

    always @(posedge dest_clk) begin
        sync_reg_1 <= async_in;
        sync_reg_2 <= sync_reg_1;
        sync_out   <= sync_reg_2;
    end
endmodule