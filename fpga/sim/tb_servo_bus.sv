// ============================================================================
// tb_servo_bus.sv — 1kHz 时隙调度 + 协议帧 TB（字节级，golden 对照）
//
// 验证项（对照 interface.md §6 预算表与 scs_protocol.py golden）：
//   1. 时隙 t0：SYNC_WRITE 32B 帧逐字节断言
//      FF FF FE 1C 83 2A 02 (id,pos_l,pos_h)×8 CS
//      target=8×2048(raw 0x800) 时 CS=0xD2（手工锚点）
//   2. t1/t2：READ 帧 FF FF ID 04 02 3A 08 B8 轮询 #1/#2，i/j 指针 +2 轮转
//   3. slave 响应 → ctrl 回读寄存器更新（meas_pos/meas_load/temp）
//   4. drop 注入 → online_bitmap 清位
//   5. 事件帧：速度事件 → 广播 WRITE 0x2E
// 运行：xsim / iverilog（字节级，无需位时序）
// ============================================================================
`timescale 1ns / 1ps
`default_nettype none

module tb_servo_bus;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    // ---- ctrl 寄存器面 ----
    logic [95:0] target_pos = {8{12'd2048}};   // 全 2048（0x800）
    logic [31:0] torque_lim = 32'h6666_6666;
    logic [7:0]  speed_raw  = 8'd3;
    logic        torque_on = 0;
    logic        speed_event = 0;
    logic        evt_torque_valid = 0;
    logic [7:0]  evt_torque_arg = 0;

    logic [15:0] meas_pos [8];
    logic [15:0] meas_load [8];
    logic [7:0]  meas_temp [8];
    logic [7:0]  online_bitmap;
    logic [31:0] loop_timestamp;

    // ---- 协议/从机互连（字节级）----
    logic        p_tx_start;
    scs_pkg::frame_type_e p_tx_type;
    logic [2:0]  p_tx_read_id;
    logic [7:0]  p_tx_arg;
    logic [95:0] p_tx_pos;
    logic        p_tx_valid, p_tx_done, p_tx_ready;
    logic [7:0]  p_tx_byte;
    logic        u_rx_valid;
    logic [7:0]  u_rx_byte;
    logic        r_frame_done, r_frame_err;
    logic [3:0]  r_resp_id;
    logic [63:0] r_resp_data;

    logic [15:0] load_inject [8];
    logic [7:0]  drop_mask = 8'h00;

    servo_bus_ctrl #(.SLOT_CYC(2_000), .READ_TIMEOUT_CYC(300)) u_ctrl (  // 时隙缩到 20µs 加速
        .clk(clk), .rst_n(rst_n),
        .tx_start(p_tx_start), .tx_type(p_tx_type), .tx_read_id(p_tx_read_id),
        .tx_arg(p_tx_arg), .tx_pos(p_tx_pos), .tx_done(p_tx_done),
        .rx_frame_done(r_frame_done), .rx_frame_err(r_frame_err),
        .rx_resp_id(r_resp_id), .rx_resp_data(r_resp_data),
        .target_pos(target_pos), .torque_lim(torque_lim), .speed_raw(speed_raw),
        .torque_on(torque_on), .speed_event(speed_event),
        .evt_torque_valid(evt_torque_valid), .evt_torque_arg(evt_torque_arg),
        .meas_pos(meas_pos), .meas_load(meas_load), .meas_temp(meas_temp),
        .online_bitmap(online_bitmap), .loop_timestamp(loop_timestamp)
    );

    scs_protocol_tx u_ptx (
        .clk(clk), .rst_n(rst_n),
        .start(p_tx_start), .frame_type(p_tx_type), .read_id(p_tx_read_id),
        .arg_field(p_tx_arg), .pos_raw(p_tx_pos),
        .byte_valid(p_tx_valid), .byte_data(p_tx_byte),
        .byte_ready(p_tx_ready), .done(p_tx_done)
    );

    scs_protocol_rx u_prx (
        .clk(clk), .rst_n(rst_n),
        .byte_valid(u_rx_valid), .byte_data(u_rx_byte),
        .frame_done(r_frame_done), .frame_err(r_frame_err),
        .resp_id(r_resp_id), .resp_err(), .resp_data(r_resp_data)
    );

    scs_slave_model u_slave (
        .clk(clk), .rst_n(rst_n),
        .tx_byte_valid(p_tx_valid), .tx_byte_data(p_tx_byte),
        .rx_byte_valid(u_rx_valid), .rx_byte_data(u_rx_byte),
        .load_inject(load_inject), .drop_mask(drop_mask)
    );

    // p_tx_ready：字节立即被消费（tx_done 作 ready，TB 无真实 uart）
    assign p_tx_ready = 1'b1;

    // ---- 帧捕获 ----
    logic [7:0] cap [64];
    int unsigned cap_len;
    int unsigned cap_cnt;
    logic        cap_on;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cap_len <= 0; cap_cnt <= 0; cap_on <= 0;
        end else begin
            if (p_tx_start) begin
                cap_cnt <= 0; cap_len <= 0; cap_on <= 1;
            end
            if (cap_on && p_tx_valid) begin
                cap[cap_cnt] <= p_tx_byte;
                cap_cnt <= cap_cnt + 1;
                cap_len <= cap_cnt + 1;
                if (cap_cnt >= 63) cap_on <= 0;
            end
            if (p_tx_done) cap_on <= 0;
        end
    end

    task automatic expect_byte(input int unsigned i, input byte v, input string tag);
        assert (cap[i] == v)
        else $error("%s: byte[%0d]=0x%02X expect 0x%02X", tag, i, cap[i], v);
    endtask

    initial begin
        for (int i = 0; i < 8; i++) load_inject[i] = '0;
        repeat (10) @(posedge clk); rst_n = 1;
        // 等第一个 SYNC_WRITE 帧（时隙 0 触发）
        wait (p_tx_done == 1'b1); @(posedge clk);
        // ---- 断言 1：SYNC_WRITE 32B 帧结构 ----
        expect_byte(0, 8'hFF, "sync");
        expect_byte(1, 8'hFF, "sync");
        expect_byte(2, 8'hFE, "sync");
        expect_byte(3, 8'h1C, "sync");   // LEN=28
        expect_byte(4, 8'h83, "sync");
        expect_byte(5, 8'h2A, "sync");
        expect_byte(6, 8'h02, "sync");
        for (int s = 0; s < 8; s++) begin
            expect_byte(7 + 3*s,     byte'(s + 1), "sync");
            expect_byte(8 + 3*s,     8'h00, "sync");   // 2048 = 0x800 → low 0x00
            expect_byte(9 + 3*s,     8'h08, "sync");   // high 0x08
        end
        expect_byte(31, 8'hD2, "sync");  // 手工锚点 CS
        $display("T1 PASS: SYNC_WRITE frame (32B, CS=0xD2)");

        // ---- 等 READ #1 帧 ----
        @(posedge p_tx_start);
        @(posedge p_tx_done); @(posedge clk);
        expect_byte(0, 8'hFF, "read1");
        expect_byte(1, 8'hFF, "read1");
        expect_byte(2, 8'h01, "read1");
        expect_byte(3, 8'h04, "read1");
        expect_byte(4, 8'h02, "read1");
        expect_byte(5, 8'h3A, "read1");
        expect_byte(6, 8'h08, "read1");
        expect_byte(7, 8'hB6, "read1");  // CS = ~0x49（01+04+02+3A+08）
        $display("T2 PASS: READ #1 frame");
        // slave 响应 → 回读更新
        repeat (200) @(posedge clk);
        assert (online_bitmap[0] == 1'b1) else $error("T3: servo1 online");
        assert (meas_pos[0] == 16'd2048) else $error("T3: meas_pos=%0d", meas_pos[0]);

        // ---- 掉线注入：舵机 1 静默 → READ 超时清 online（保持注入期间断言）----
        drop_mask = 8'b0000_0001;
        repeat (6_000) @(posedge clk);   // 数个时隙，超时生效
        assert (online_bitmap[0] == 1'b0) else $error("T4: servo1 offline expected, bitmap=%02X", online_bitmap);
        $display("T4 PASS: drop injection -> offline bit");
        drop_mask = 8'h00;
        repeat (4_000) @(posedge clk);   // 恢复在线
        assert (online_bitmap[0] == 1'b1) else $error("T4b: servo1 back online");

        // ---- 事件帧：速度事件 → 广播 WRITE 0x2E ----
        speed_event <= 1'b1;
        @(posedge clk); speed_event <= 1'b0;
        repeat (4_000) @(posedge clk);
        // 最近捕获帧应为广播速度帧 8B：FF FF FE 04 03 2E 03 CS
        expect_byte(0, 8'hFF, "evt");
        expect_byte(1, 8'hFF, "evt");
        expect_byte(2, 8'hFE, "evt");
        expect_byte(3, 8'h04, "evt");
        expect_byte(4, 8'h03, "evt");
        expect_byte(5, 8'h2E, "evt");
        expect_byte(6, 8'h03, "evt");    // speed_raw=3
        expect_byte(7, 8'hC9, "evt");    // CS = ~(FE+04+03+2E+03) = ~0x36 = 0xC9（golden 锚点）
        $display("T5 PASS: speed event frame");

        $display("tb_servo_bus: ALL PASS");
        $finish;
    end

    initial begin
        #2_000_000;  // 2ms 仿真看门狗
        $error("watchdog timeout");
        $finish;
    end
endmodule
