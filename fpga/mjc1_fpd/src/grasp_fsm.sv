// ============================================================================
// grasp_fsm.sv — 力控抓握状态机（作品 FPGA 核心，评分 25 分项）
//
// 行为权威：host/app/control/backend_sim.py 内软件状态机（golden model #2），
// 迁移条件逐条对照：
//   IDLE --CMD01(enable)--> PREGRASP[力矩on, 目标=预张快照, 0.3s]
//     --> CLOSING[目标=TARGET寄存器, 速度事件一次, 监视任一在线通道
//                 load >= level*64（对照 TORQUE_LEVEL_STEP=64）]
//       --> HOLD[锁存回读位置为新目标; 到位/触力→grasped, 3s 超时→timeout]
//         --CMD02--> RELEASING[目标=预张快照, 0.5s] --> IDLE
//   HOLD 中任一舵机掉线 → PROTECT[力矩off]；CMD04 arg=1 手动复位 → IDLE
//   CMD03：快照当前 TARGET_i 为预张角（host 先写角再发 0x03）
//   estop 电平或 PROTECT：力矩事件 off
// ============================================================================
`timescale 1ns/1ps
`default_nettype none

module grasp_fsm #(
    parameter int CLK_HZ      = 100_000_000,
    parameter int TICK_CYC    = 1_000_000,  // 10ms 节拍周期数（TB 缩小加速仿真）
    parameter int PREGRASP_T  = 30,         // ×10ms = 0.3s（对照 PREGRASP_S）
    parameter int RELEASING_T = 50,         // 0.5s
    parameter int CLOSING_T   = 300         // 3.0s
) (
    input  wire        clk,
    input  wire        rst_n,
    // 寄存器命令（axi_lite_regs 写脉冲）
    input  wire        cmd_valid,
    input  wire [7:0]  cmd_id,        // 0x01 抓取 0x02 释放 0x03 预张快照 0x04 力矩(arg=1/0)
    input  wire [7:0]  cmd_arg,
    input  wire        estop,         // CTRL.estop 电平
    input  wire        enable,        // CTRL.enable
    // 抓取参数（寄存器面）
    input  wire [95:0] target_pos,    // 8×12bit raw（抓取目标）
    input  wire [31:0] torque_lim,    // 8×4bit 等级（阈值 = level<<6）
    input  wire [7:0]  speed_raw,
    // 回读（servo_bus_ctrl）
    input  wire [15:0] meas_load   [8],
    input  wire [15:0] meas_pos    [8],
    input  wire [7:0]  online_bitmap,
    // 控制输出（servo_bus_ctrl）
    output logic [95:0] ctrl_target,
    output logic        torque_on,
    output logic        speed_event,
    output logic        evt_torque_valid,
    output logic [7:0]  evt_torque_arg,
    // 状态寄存器面
    output logic [2:0]  fsm_state,
    output logic        fsm_busy,
    output logic        grasped,
    output logic        timeout_flag,
    output logic        fault
);
    localparam int unsigned TL_STEP_SH  = 6;   // 阈值 = level << 6

    typedef enum logic [2:0] {
        S_IDLE = 3'd0, S_PREGRASP = 3'd1, S_CLOSING = 3'd2,
        S_HOLD = 3'd3, S_RELEASING = 3'd4, S_PROTECT = 3'd5
    } state_e;

    state_e st, st_next;
    logic [15:0] t_10ms;      // 态内 10ms 计数
    logic [95:0] pregrasp_snap;
    logic [95:0] hold_snap;
    logic        hold_valid;
    logic        load_hit_q;  // 迁移瞬间采样（区分 grasped / timeout）
    logic        speed_fired;

    // ---- 10ms tick（TICK_CYC 参数化：板端=1_000_000；TB 缩小加速仿真）----
    localparam int MS_CYC = TICK_CYC / 10;      // 1ms 周期数
    logic [19:0] ms_cnt;
    wire tick10 = (ms_cnt == MS_CYC - 1);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) ms_cnt <= '0;
        else ms_cnt <= tick10 ? '0 : ms_cnt + 1'b1;
    end
    logic [5:0] ms10_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms10_cnt <= '0;
        end else if (tick10) begin
            ms10_cnt <= (ms10_cnt == 9) ? '0 : ms10_cnt + 1'b1;
        end
    end
    wire tick_10ms = tick10 && (ms10_cnt == 0);  // 10ms 精确节拍

    // ---- 力控判定：任一在线通道负载达到阈值 ----
    logic load_hit_c;
    always_comb begin
        load_hit_c = 1'b0;
        for (int i = 0; i < 8; i++) begin
            logic [15:0] thr;
            thr = {12'd0, torque_lim[i*4 +: 4]} << TL_STEP_SH;
            if (online_bitmap[i] && torque_lim[i*4 +: 4] != 4'd0 &&
                meas_load[i] >= thr) begin
                load_hit_c = 1'b1;
            end
        end
    end

    // ---- 组合迁移 ----
    always_comb begin
        st_next = st;  // 默认保持
        unique case (st)
            S_IDLE:      if (cmd_valid && cmd_id == 8'h01 && enable && !estop)
                             st_next = S_PREGRASP;
            S_PREGRASP:  if (tick_10ms && t_10ms >= PREGRASP_T[15:0]) st_next = S_CLOSING;
            S_CLOSING:   if (load_hit_c ||
                             (tick_10ms && t_10ms >= CLOSING_T[15:0])) st_next = S_HOLD;
            S_HOLD: begin
                if (online_bitmap != 8'hFF)              st_next = S_PROTECT;
                else if (cmd_valid && cmd_id == 8'h02)   st_next = S_RELEASING;
            end
            S_RELEASING: if (tick_10ms && t_10ms >= RELEASING_T[15:0]) st_next = S_IDLE;
            S_PROTECT:   if (cmd_valid && cmd_id == 8'h04 && cmd_arg == 8'd1)
                             st_next = S_IDLE;
            default: st_next = S_IDLE;
        endcase
        // estop 任意态急停（IDLE 除外——无动作可停）
        if (estop && st != S_IDLE && st != S_PROTECT) st_next = S_PROTECT;
    end

    // ---- 状态寄存 + 副作用 ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_IDLE;
            t_10ms <= '0;
            pregrasp_snap <= '0;
            hold_snap <= '0; hold_valid <= 1'b0;
            torque_on <= 1'b0;
            evt_torque_valid <= 1'b0;
            evt_torque_arg <= 8'd0;
            timeout_flag <= 1'b0;
            load_hit_q <= 1'b0;
        end else begin
            // One-cycle event pulse; keep the output defined outside events.
            evt_torque_valid <= 1'b0;
            if (st != st_next) t_10ms <= '0;
            else if (tick_10ms) t_10ms <= t_10ms + 1'b1;
            st <= st_next;

            // 迁移瞬间采样（区分 grasped/timeout）
            if (st == S_CLOSING && st_next == S_HOLD) begin
                load_hit_q <= load_hit_c;
                timeout_flag <= !load_hit_c;   // 无触力 → 超时保持
                // 锁存回读位置为 HOLD 目标（对照 Python _closing_hold_raw）
                hold_snap <= {meas_pos[7][11:0], meas_pos[6][11:0],
                              meas_pos[5][11:0], meas_pos[4][11:0],
                              meas_pos[3][11:0], meas_pos[2][11:0],
                              meas_pos[1][11:0], meas_pos[0][11:0]};
                hold_valid <= 1'b1;
            end
            if (st_next == S_PREGRASP) timeout_flag <= 1'b0;
            if (st_next == S_IDLE) begin
                hold_valid <= 1'b0;
                timeout_flag <= 1'b0;
            end

            // 副作用：力矩事件
            if (st_next == S_PREGRASP && !torque_on) begin
                torque_on <= 1'b1;
                evt_torque_valid <= 1'b1;
                evt_torque_arg <= 8'd1;
            end
            if (st_next == S_PROTECT && torque_on) begin
                torque_on <= 1'b0;
                evt_torque_valid <= 1'b1;
                evt_torque_arg <= 8'd0;
            end
            // CMD04 手动力矩（IDLE 下）
            if (cmd_valid && cmd_id == 8'h04 && st == S_IDLE) begin
                if (cmd_arg == 8'd1 && !torque_on) begin
                    torque_on <= 1'b1;
                    evt_torque_valid <= 1'b1; evt_torque_arg <= 8'd1;
                end else if (cmd_arg == 8'd0 && torque_on) begin
                    torque_on <= 1'b0;
                    evt_torque_valid <= 1'b1; evt_torque_arg <= 8'd0;
                end
            end
            // CMD03 预张快照（任意态允许，抓取前使用）
            if (cmd_valid && cmd_id == 8'h03) pregrasp_snap <= target_pos;
        end
    end

    // 速度事件：进入 CLOSING 时触发一次
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            speed_event <= 1'b0; speed_fired <= 1'b0;
        end else begin
            speed_event <= 1'b0;
            if (st_next == S_PREGRASP) speed_fired <= 1'b0;
            if (st == S_PREGRASP && st_next == S_CLOSING && !speed_fired) begin
                speed_event <= 1'b1;
                speed_fired <= 1'b1;
            end
        end
    end

    // ---- 输出多路与状态字 ----
    always_comb begin
        unique case (st)
            S_PREGRASP, S_RELEASING: ctrl_target = pregrasp_snap;
            S_HOLD:                  ctrl_target = hold_snap;
            default:                 ctrl_target = target_pos;
        endcase
    end
    assign fsm_state = st;
    assign fsm_busy  = (st == S_PREGRASP) || (st == S_CLOSING) || (st == S_RELEASING);
    assign grasped   = (st == S_HOLD) && hold_valid && !timeout_flag;
    assign fault     = (st == S_PROTECT);
endmodule
