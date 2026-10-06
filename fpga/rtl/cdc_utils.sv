// ============================================================================
// cdc_utils.sv — CDC 小工具集（interface.md §1：寄存器侧自动 CDC）
//   sync_2ff : 两级触发器同步（电平信号跨时钟域）
//   pulse_sync : 脉冲同步（事件脉冲跨域，握手握手法）
// ============================================================================
`default_nettype none

module sync_2ff #(
    parameter int STAGES = 2,
    parameter bit INIT   = 1'b0
) (
    input  wire clk,
    input  wire rst_n,
    input  wire d_in,
    output logic q_out
);
    (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] ff;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) ff <= '{default: INIT};
        else        ff <= {ff[STAGES-2:0], d_in};
    end
    assign q_out = ff[STAGES-1];
endmodule

module pulse_sync (
    input  wire clk_src,   // 源域
    input  wire rst_src_n,
    input  wire pulse_in,  // 源域单周期脉冲
    input  wire clk_dst,   // 目的域
    input  wire rst_dst_n,
    output logic pulse_out // 目的域单周期脉冲
);
    // 源域：脉冲转电平翻转
    logic toggle_src;
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) toggle_src <= 1'b0;
        else if (pulse_in) toggle_src <= ~toggle_src;
    end
    // 目的域：同步 + 边沿检测还原脉冲
    logic [2:0] sync;
    (* ASYNC_REG = "TRUE" *) logic [2:0] ff;
    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) ff <= '0;
        else            ff <= {ff[1:0], toggle_src};
    end
    assign pulse_out = ff[2] ^ ff[1];
    logic unused;
    assign unused = sync[0];
endmodule
