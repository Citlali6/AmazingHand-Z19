// ============================================================================
// tb_grasp_fsm.sv — 力控状态机 TB（与 backend_sim.py golden 状态轨迹对照）
//
// 场景（对应 Python 测试 test_fsm_full_cycle/timeout/estop/掉线）：
//   1. 预张快照 → CMD01 → PREGRASP(力矩事件) → 0.35s → CLOSING(速度事件)
//   2. 负载注入超阈值 → HOLD 且 grasped=1（力控抓稳）
//   3. CMD02 → RELEASING → IDLE
//   4. 再次抓取，负载保持低 → 3.2s 超时 HOLD 且 timeout=1, grasped=0
//   5. HOLD 中掉线注入 → PROTECT(fault=1) → CMD04 arg1 → IDLE
//   6. estop 急停 → PROTECT
// 运行：xsim/iverilog，时钟 100MHz（10ns 周期）
// ============================================================================
`timescale 1ns / 1ps
`default_nettype none

module tb_grasp_fsm;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;  // 100MHz

    logic        cmd_valid = 0;
    logic [7:0]  cmd_id = '0, cmd_arg = '0;
    logic        estop = 0, enable = 1;
    logic [95:0] target_pos = '0;
    logic [31:0] torque_lim = 32'h6666_6666;  // 全通道 6 级（阈值 384）
    logic [7:0]  speed_raw = 8'd3;
    logic [15:0] meas_load [8];
    logic [15:0] meas_pos  [8];
    logic [7:0]  online_bitmap = 8'hFF;

    logic [95:0] ctrl_target;
    logic        torque_on, speed_event;
    logic        evt_torque_valid;
    logic [7:0]  evt_torque_arg;
    logic [2:0]  fsm_state;
    logic        fsm_busy, grasped, timeout_flag, fault;

    grasp_fsm #(
        .TICK_CYC(1_000),      // 仿真：10ms tick = 10µs（缩 1000×）
        .PREGRASP_T(30),       // 0.3ms 仿真
        .RELEASING_T(50),      // 0.5ms
        .CLOSING_T(300)        // 3ms 超时
    ) u_dut (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(cmd_valid), .cmd_id(cmd_id), .cmd_arg(cmd_arg),
        .estop(estop), .enable(enable),
        .target_pos(target_pos), .torque_lim(torque_lim), .speed_raw(speed_raw),
        .meas_load(meas_load), .meas_pos(meas_pos), .online_bitmap(online_bitmap),
        .ctrl_target(ctrl_target),
        .torque_on(torque_on), .speed_event(speed_event),
        .evt_torque_valid(evt_torque_valid), .evt_torque_arg(evt_torque_arg),
        .fsm_state(fsm_state), .fsm_busy(fsm_busy), .grasped(grasped),
        .timeout_flag(timeout_flag), .fault(fault)
    );

    // golden 状态编码（与 interface.md/Python FsmState 一致）
    localparam [2:0] S_IDLE = 0, S_PREGRASP = 1, S_CLOSING = 2,
                     S_HOLD = 3, S_RELEASING = 4, S_PROTECT = 5;

    task automatic do_cmd(input [7:0] id, input [7:0] arg);
        @(posedge clk); cmd_valid <= 1; cmd_id <= id; cmd_arg <= arg;
        @(posedge clk); cmd_valid <= 0;
    endtask

    initial begin
        for (int i = 0; i < 8; i++) begin
            meas_load[i] = '0; meas_pos[i] = 12'd2048;
        end
        // 复位
        repeat (10) @(posedge clk); rst_n = 1;
        repeat (10) @(posedge clk);

        // ---- 场景 1/2/3：预张快照 + 力控抓取全周期 ----
        target_pos = {8{12'd3071}};              // 抓取目标 90°（raw 3071）
        do_cmd(8'h03, 8'h00);                    // 预张快照（当前 TARGET 为张open? 先写张开角）
        target_pos = {8{12'd1649}};              // 预张角 -35°（raw 1649）
        do_cmd(8'h03, 8'h00);                    // 快照预张角
        target_pos = {8{12'd3071}};              // 恢复抓取目标
        do_cmd(8'h01, 8'h00);                    // 启动
        repeat (10) @(posedge clk);
        assert (fsm_state == S_PREGRASP) else $error("S1: expect PREGRASP, got %0d", fsm_state);
        assert (evt_torque_valid && evt_torque_arg == 8'd1) else $error("S1: torque-on event missing");
        // PREGRASP 0.35ms（>0.3ms 阈值）
        repeat (35_000) @(posedge clk);
        assert (fsm_state == S_CLOSING) else $error("S2: expect CLOSING, got %0d", fsm_state);
        assert (speed_event) else $error("S2: speed event missing");

        // 注入负载 500 ≥ 阈值 384 → 力控 HOLD
        for (int i = 0; i < 8; i++) meas_load[i] = 16'd500;
        repeat (1000) @(posedge clk);
        assert (fsm_state == S_HOLD) else $error("S2: expect HOLD, got %0d", fsm_state);
        assert (grasped && !timeout_flag) else $error("S2: grasped=%b timeout=%b", grasped, timeout_flag);

        // 释放 → IDLE
        do_cmd(8'h02, 8'h00);
        repeat (60_000) @(posedge clk);  // 0.6ms > RELEASING 0.5ms
        assert (fsm_state == S_IDLE) else $error("S3: expect IDLE, got %0d", fsm_state);
        for (int i = 0; i < 8; i++) meas_load[i] = '0;

        // ---- 场景 4：无负载 → 超时 HOLD（timeout=1, grasped=0）----
        do_cmd(8'h01, 8'h00);
        repeat (340_000) @(posedge clk);  // 3.4ms > PREGRASP+CLOSING 3.3ms
        assert (fsm_state == S_HOLD) else $error("S4: expect HOLD, got %0d", fsm_state);
        assert (timeout_flag && !grasped) else $error("S4: timeout=%b grasped=%b", timeout_flag, grasped);
        do_cmd(8'h02, 8'h00);
        repeat (600_000) @(posedge clk);

        // ---- 场景 5：HOLD 掉线 → PROTECT → 手动复位 ----
        do_cmd(8'h01, 8'h00);
        for (int i = 0; i < 8; i++) meas_load[i] = 16'd500;
        repeat (1000) @(posedge clk);
        assert (fsm_state == S_HOLD) else $error("S5a");
        online_bitmap = 8'b1011_1111;  // 舵机 6 掉线
        repeat (100) @(posedge clk);
        assert (fsm_state == S_PROTECT && fault) else $error("S5b: expect PROTECT");
        assert (!torque_on) else $error("S5b: torque must be cut");
        online_bitmap = 8'hFF;
        do_cmd(8'h04, 8'h01);          // 手动复位
        repeat (100) @(posedge clk);
        assert (fsm_state == S_IDLE) else $error("S5c: expect IDLE");

        // ---- 场景 6：estop ----
        do_cmd(8'h01, 8'h00);
        repeat (1000) @(posedge clk);
        estop = 1; repeat (100) @(posedge clk);
        assert (fsm_state == S_PROTECT && fault) else $error("S6: estop → PROTECT");
        estop = 0;

        $display("tb_grasp_fsm: ALL PASS");
        $finish;
    end

    initial begin
        #5_000_000;  // 5ms 仿真看门狗（超时场景 3.4ms）
        $error("watchdog timeout");
        $finish;
    end
endmodule
