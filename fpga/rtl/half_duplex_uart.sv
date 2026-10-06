// ============================================================================
// half_duplex_uart.sv — 单线半双工 UART @1Mbps（SCS0009 总线物理层）
//
// 时序（100MHz clk）：BIT_CYC=100 → 1bit/µs = 1Mbps；
// RX 过采样 4×（25cyc），位中心采样；起始位下降沿检测 + 二次确认。
// 电气：inout 三态——TX 帧期间推挽驱动，空闲/接收时释放（bus_line 由
// TXS0108E + 总线上拉保持高电平）。帧间换向由 servo_bus_ctrl 的
// 事务状态机保证（发完→等待→收），本模块只管"一次一字节"。
// ============================================================================
`default_nettype none

module half_duplex_uart #(
    parameter int BIT_CYC = 100,   // 100MHz / 1Mbps
    parameter int SAMPLE_CYC = 25  // RX 过采样周期
) (
    input  wire       clk,
    input  wire       rst_n,
    // TX（字节级，来自 scs_protocol_tx）
    input  wire       tx_start,
    input  wire [7:0] tx_byte,
    output logic      tx_busy,
    output logic      tx_done,
    // RX（字节级，送 scs_protocol_rx）
    output logic       rx_valid,
    output logic [7:0] rx_byte,
    // 总线
    inout  wire        bus_line
);
    // ------------------------------------------------------------------
    // TX
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_e;
    tx_state_e tx_st;
    int unsigned bit_cnt;    // 位内周期计数
    int unsigned bit_idx;    // 数据位索引
    logic [7:0] sh_tx;
    logic       line_out;    // TX 驱动电平
    logic       tx_drive;    // 三态使能

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_st <= TX_IDLE; bit_cnt <= 0; bit_idx <= 0;
            sh_tx <= '0; tx_done <= 1'b0; line_out <= 1'b1; tx_drive <= 1'b0;
        end else begin
            tx_done <= 1'b0;
            unique case (tx_st)
                TX_IDLE: if (tx_start) begin
                    sh_tx <= tx_byte; bit_cnt <= 0; bit_idx <= 0;
                    tx_drive <= 1'b1; line_out <= 1'b0;   // 起始位
                    tx_st <= TX_START;
                end
                TX_START: begin
                    if (bit_cnt == BIT_CYC - 1) begin
                        bit_cnt <= 0; line_out <= sh_tx[0]; tx_st <= TX_DATA;
                    end else bit_cnt <= bit_cnt + 1;
                end
                TX_DATA: begin
                    if (bit_cnt == BIT_CYC - 1) begin
                        bit_cnt <= 0;
                        if (bit_idx == 7) begin
                            line_out <= 1'b1; tx_st <= TX_STOP;  // 停止位
                        end else begin
                            bit_idx <= bit_idx + 1;
                            line_out <= sh_tx[bit_idx + 1];
                        end
                    end else bit_cnt <= bit_cnt + 1;
                end
                TX_STOP: begin
                    if (bit_cnt == BIT_CYC - 1) begin
                        bit_cnt <= 0; tx_drive <= 1'b0;      // 释放总线
                        tx_done <= 1'b1; tx_st <= TX_IDLE;
                    end else bit_cnt <= bit_cnt + 1;
                end
            endcase
        end
    end
    assign tx_busy = (tx_st != TX_IDLE);
    assign bus_line = tx_drive ? line_out : 1'bz;

    // ------------------------------------------------------------------
    // RX：4× 过采样，下降沿捕获起始位，位中心采样
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_e;
    rx_state_e rx_st;
    int unsigned rx_cnt;
    int unsigned rx_bit;
    logic [7:0] sh_rx;
    logic       bus_q;       // 过采样寄存器
    logic       falling;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) bus_q <= 1'b1;
        else        bus_q <= bus_line;
    end
    assign falling = bus_q & ~bus_line;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_st <= RX_IDLE; rx_cnt <= 0; rx_bit <= 0;
            sh_rx <= '0; rx_valid <= 1'b0; rx_byte <= '0;
        end else begin
            rx_valid <= 1'b0;
            unique case (rx_st)
                RX_IDLE: begin
                    if (falling) begin
                        rx_cnt <= 0; rx_st <= RX_START;
                    end
                end
                RX_START: begin
                    // 半位后确认起始位仍为低（滤毛刺）
                    if (rx_cnt == BIT_CYC / 2 - 1) begin
                        if (!bus_line) begin
                            rx_cnt <= 0; rx_bit <= 0; rx_st <= RX_DATA;
                        end else rx_st <= RX_IDLE;
                    end else rx_cnt <= rx_cnt + 1;
                end
                RX_DATA: begin
                    if (rx_cnt == SAMPLE_CYC - 1) begin
                        sh_rx[rx_bit] <= bus_line;
                        rx_cnt <= 0;
                        if (rx_bit == 7) rx_st <= RX_STOP;
                        else rx_bit <= rx_bit + 1;
                    end else rx_cnt <= rx_cnt + 1;
                end
                RX_STOP: begin
                    if (rx_cnt == SAMPLE_CYC - 1) begin
                        if (bus_line) begin  // 停止位必须为高
                            rx_valid <= 1'b1; rx_byte <= sh_rx;
                        end
                        rx_cnt <= 0; rx_st <= RX_IDLE;
                    end else rx_cnt <= rx_cnt + 1;
                end
            endcase
        end
    end
endmodule
