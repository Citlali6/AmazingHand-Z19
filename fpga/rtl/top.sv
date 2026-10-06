// ============================================================================
// top.sv — PL 顶层：AXI 寄存器 + 力控状态机 + 总线调度 + 半双工 UART
//
// 数据流（architecture.md §4 下半段）：
//   axi_lite_regs → grasp_fsm → servo_bus_ctrl → scs_protocol_tx
//     → half_duplex_uart → bus_line（TXS0108E 电平转换 → SCS0009 总线）
//   总线 → uart rx → scs_protocol_rx → ctrl 回读寄存器 → axi 状态面
// 时钟：PL_CLK0 200MHz 差分入片 → MMCM 分频 100MHz（本文件内 MMCM 由 BD
//   提供；若以纯 RTL 集成，使用下方 clk_wiz 例化段）。
// ============================================================================
`default_nettype none

module top (
    input  wire        pl_clk0_p,     // 200MHz 差分（H24/G25）
    input  wire        pl_clk0_n,
    input  wire        rst_n_btn,     // 复位链由 PS/外部保证；板载按键低有效（D4）
    // 舵机总线（FMC1 LA02_P=L17，经 TXS0108E 电平转换到 5V TTL）
    inout  wire        servo_data,
    // 状态指示
    output wire        heartbeat,     // 1Hz 心跳（PL_LED1=B3）
    // AXI4-Lite（BD 内 Zynq PS M_AXI_HPM0 直连，地址 0x4000_0000）
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,
    output wire        irq
);
    // ---- 时钟/复位（200MHz 差分 → IBUFDS → MMCM 100MHz）----
    wire clk_200;
    IBUFDS ibufds_clk (
        .I(pl_clk0_p), .O(clk_200), .IB(pl_clk0_n), .ZN()
    );
    wire clk_100, mmcm_locked, mmcm_rst = ~rst_n_btn;
    wire clk_fb;
    MMCME2_BASE #(
        .CLKIN1_PERIOD(5.0),          // 200MHz
        .CLKFBOUT_MULT_F(5.0),        // 1000MHz VCO
        .DIVCLK_DIVIDE(1),
        .CLKOUT0_DIVIDE_F(10.0)       // 100MHz
    ) mmcm (
        .CLKIN1(clk_200), .CLKFBIN(clk_fb), .CLKFBOUT(clk_fb),
        .RST(mmcm_rst), .PWRDWN(1'b0), .LOCKED(mmcm_locked),
        .CLKOUT0(clk_100), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(),
        .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
        .CLKOUT4(), .CLKOUT5(), .CLKOUT6(),
        .CLKFBOUTB(), .CLKINSEL(1'b1),
        .CLKIN2(1'b0)
    );
    // 复位同步释放
    logic rst_n_sync = 1'b0;
    logic [3:0] rst_ff;
    always_ff @(posedge clk_100 or negedge mmcm_locked) begin
        if (!mmcm_locked) rst_ff <= '0;
        else              rst_ff <= {rst_ff[2:0], 1'b1};
    end
    assign rst_n_sync = rst_ff[3];

    // ---- 心跳（25bit 计数器 @100MHz ≈ 0.34s 翻转，肉眼可见闪烁）----
    logic [24:0] hb_cnt;
    logic        hb_q;
    always_ff @(posedge clk_100 or negedge rst_n_sync) begin
        if (!rst_n_sync) hb_cnt <= '0;
        else             hb_cnt <= hb_cnt + 1'b1;
    end
    always_ff @(posedge clk_100 or negedge rst_n_sync) begin
        if (!rst_n_sync) hb_q <= 1'b0;
        else if (&hb_cnt) hb_q <= ~hb_q;
    end
    assign heartbeat = hb_q;

    // ---- AXI 寄存器 ----
    logic        cmd_valid;
    logic [7:0]  cmd_id, cmd_arg;
    logic [95:0] target_pos;
    logic [31:0] torque_lim;
    logic [7:0]  speed_raw;
    logic        enable, estop;
    logic [2:0]  fsm_state;
    logic        fsm_busy, fsm_grasped, fsm_timeout, fsm_fault;
    logic [15:0] meas_pos   [8];
    logic [15:0] meas_load  [8];
    logic [7:0]  meas_temp  [8];
    logic [7:0]  online_bitmap;
    logic [31:0] loop_timestamp;

    axi_lite_regs #(.BASE_ADDR(32'h4000_0000)) u_regs (
        .clk(clk_100), .rst_n(rst_n_sync),
        .awaddr(s_axi_awaddr), .awvalid(s_axi_awvalid), .awready(s_axi_awready),
        .wdata(s_axi_wdata), .wstrb(s_axi_wstrb), .wvalid(s_axi_wvalid), .wready(s_axi_wready),
        .bresp(s_axi_bresp), .bvalid(s_axi_bvalid), .bready(s_axi_bready),
        .araddr(s_axi_araddr), .arvalid(s_axi_arvalid), .arready(s_axi_arready),
        .rdata(s_axi_rdata), .rresp(s_axi_rresp), .rvalid(s_axi_rvalid), .rready(s_axi_rready),
        .cmd_valid(cmd_valid), .cmd_id(cmd_id), .cmd_arg(cmd_arg),
        .target_pos(target_pos), .torque_lim(torque_lim), .speed_raw(speed_raw),
        .enable(enable), .estop(estop),
        .fsm_state(fsm_state), .fsm_busy(fsm_busy), .fsm_grasped(fsm_grasped),
        .fsm_timeout(fsm_timeout), .fsm_fault(fsm_fault),
        .meas_pos(meas_pos), .meas_load(meas_load), .meas_temp(meas_temp),
        .online_bitmap(online_bitmap), .loop_timestamp(loop_timestamp),
        .irq(irq)
    );

    // ---- 力控状态机 ----
    logic [95:0] ctrl_target;
    logic        torque_on, speed_event;
    logic        evt_torque_valid;
    logic [7:0]  evt_torque_arg;

    grasp_fsm u_fsm (
        .clk(clk_100), .rst_n(rst_n_sync),
        .cmd_valid(cmd_valid), .cmd_id(cmd_id), .cmd_arg(cmd_arg),
        .estop(estop), .enable(enable),
        .target_pos(target_pos), .torque_lim(torque_lim), .speed_raw(speed_raw),
        .meas_load(meas_load), .meas_pos(meas_pos), .online_bitmap(online_bitmap),
        .ctrl_target(ctrl_target),
        .torque_on(torque_on), .speed_event(speed_event),
        .evt_torque_valid(evt_torque_valid), .evt_torque_arg(evt_torque_arg),
        .fsm_state(fsm_state), .fsm_busy(fsm_busy), .grasped(fsm_grasped),
        .timeout_flag(fsm_timeout), .fault(fsm_fault)
    );

    // ---- 总线调度器 + 协议引擎 + 半双工 UART ----
    logic        u_tx_start;
    scs_pkg::frame_type_e u_tx_type;
    logic [2:0]  u_tx_read_id;
    logic [7:0]  u_tx_arg;
    logic [95:0] u_tx_pos;
    logic        p_tx_valid, p_tx_ready, p_tx_done;
    logic [7:0]  p_tx_byte;
    logic        u_rx_valid;
    logic [7:0]  u_rx_byte;
    logic        r_frame_done, r_frame_err;
    logic [3:0]  r_resp_id;
    logic [63:0] r_resp_data;

    servo_bus_ctrl u_ctrl (
        .clk(clk_100), .rst_n(rst_n_sync),
        .tx_start(u_tx_start), .tx_type(u_tx_type),
        .tx_read_id(u_tx_read_id), .tx_arg(u_tx_arg), .tx_pos(u_tx_pos),
        .tx_done(p_tx_done),
        .rx_frame_done(r_frame_done), .rx_frame_err(r_frame_err),
        .rx_resp_id(r_resp_id), .rx_resp_data(r_resp_data),
        .target_pos(ctrl_target),
        .torque_lim(torque_lim), .speed_raw(speed_raw),
        .torque_on(torque_on), .speed_event(speed_event),
        .evt_torque_valid(evt_torque_valid), .evt_torque_arg(evt_torque_arg),
        .meas_pos(meas_pos), .meas_load(meas_load), .meas_temp(meas_temp),
        .online_bitmap(online_bitmap), .loop_timestamp(loop_timestamp)
    );

    scs_protocol_tx u_ptx (
        .clk(clk_100), .rst_n(rst_n_sync),
        .start(u_tx_start), .frame_type(u_tx_type),
        .read_id(u_tx_read_id), .arg_field(u_tx_arg), .pos_raw(u_tx_pos),
        .byte_valid(p_tx_valid), .byte_data(p_tx_byte),
        .byte_ready(p_tx_ready), .done(p_tx_done)
    );

    scs_protocol_rx u_prx (
        .clk(clk_100), .rst_n(rst_n_sync),
        .byte_valid(u_rx_valid), .byte_data(u_rx_byte),
        .frame_done(r_frame_done), .frame_err(r_frame_err),
        .resp_id(r_resp_id), .resp_err(), .resp_data(r_resp_data)
    );

    half_duplex_uart #(.BIT_CYC(100), .SAMPLE_CYC(25)) u_uart (
        .clk(clk_100), .rst_n(rst_n_sync),
        .tx_start(p_tx_valid), .tx_byte(p_tx_byte),
        .tx_busy(), .tx_done(p_tx_ready),
        .rx_valid(u_rx_valid), .rx_byte(u_rx_byte),
        .bus_line(servo_data)
    );
endmodule
