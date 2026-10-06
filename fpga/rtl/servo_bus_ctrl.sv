// ============================================================================
// servo_bus_ctrl.sv — 1kHz 时隙调度器（interface.md §6 预算表的硬件实现）
//
// 周期事务（对照 golden model 行为）：
//   t0: SYNC_WRITE 位置（32B, 320µs）→ t1: READ #i（250µs）→ t2: READ #j（250µs）
//   i/j 轮转扫过 ID1..8 → 每舵机回读 250Hz；
//   空闲余量（~180µs）处理事件事务：广播力矩开关 / 广播速度。
// 回读更新：MEAS/LOAD/TEMP 寄存器 + online 位图（READ 超时 150µs → 掉线）。
// TIMESTAMP：100MHz 自由计数器（host 侧 P99 抖动统计，F5）。
// ============================================================================
`default_nettype none

module servo_bus_ctrl #(
    parameter int SLOT_CYC = 100_000,   // 1ms @100MHz
    parameter int READ_TIMEOUT_CYC = 15_000  // 150µs 响应超时 → 掉线
) (
    input  wire        clk,
    input  wire        rst_n,
    // 协议层（帧组包/解析）
    output logic       tx_start,
    output scs_pkg::frame_type_e tx_type,
    output logic [2:0] tx_read_id,
    output logic [7:0] tx_arg,
    output logic [95:0] tx_pos,
    input  wire        tx_done,
    input  wire        rx_frame_done,
    input  wire        rx_frame_err,
    input  wire [3:0]  rx_resp_id,
    input  wire [63:0] rx_resp_data,   // {temp,volt,load[15:0],speed[15:0],pos[15:0]}
    // 寄存器面（axi_lite_regs）
    input  wire [95:0] target_pos,     // 8×12bit raw（host 写 TARGET_i）
    input  wire [31:0] torque_lim,     // 8×4bit 等级
    input  wire [7:0]  speed_raw,      // TIMING 低 8 位
    input  wire        torque_on,      // 期望力矩态（fsm 维护）
    input  wire        speed_event,    // 速度事件脉冲（fsm 触发）
    // 状态输出
    output logic [15:0] meas_pos   [8],
    output logic [15:0] meas_load  [8],
    output logic [7:0]  meas_temp  [8],
    output logic [7:0]  online_bitmap, // 1=在线
    output logic [31:0] loop_timestamp
);
    // ---- 时隙/时间戳 ----
    int unsigned slot_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slot_cnt <= 0; loop_timestamp <= '0;
        end else begin
            loop_timestamp <= loop_timestamp + 1;
            slot_cnt <= (slot_cnt == SLOT_CYC - 1) ? 0 : slot_cnt + 1;
        end
    end

    // ---- 事务状态机 ----
    typedef enum logic [2:0] {
        ST_IDLE_SLOT, ST_T0_SYNC, ST_T1_READ, ST_T2_READ, ST_EVENT
    } st_e;
    st_e st;
    logic [2:0] poll_i, poll_j;      // 回读轮转指针（0..7 → 舵机 ID+1）
    logic       wait_resp;           // 等响应中
    int unsigned resp_cnt;
    logic [2:0] cur_read;            // 当前 READ 的舵机索引

    // 事件 pending（单槽：fsm 事件频率远低于时隙）
    logic       evt_pending;
    scs_pkg::frame_type_e evt_type;
    logic [7:0] evt_arg;

    // tx 帧发起
    logic tx_start_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= ST_IDLE_SLOT; poll_i <= 0; poll_j <= 1;
            wait_resp <= 1'b0; resp_cnt <= 0; cur_read <= 0;
            tx_start_q <= 1'b0; tx_type <= scs_pkg::F_SYNC_WRITE_POS;
            tx_read_id <= '0; tx_arg <= '0; tx_pos <= '0;
            evt_pending <= 1'b0; evt_type <= scs_pkg::F_BC_TORQUE; evt_arg <= '0;
            online_bitmap <= 8'hFF;
        end else begin
            tx_start_q <= 1'b0;
            unique case (st)
                ST_IDLE_SLOT: begin
                    if (slot_cnt == 0) begin
                        // t0：下发最新目标位置
                        tx_type <= scs_pkg::F_SYNC_WRITE_POS;
                        tx_pos  <= target_pos;
                        tx_start_q <= 1'b1;
                        st <= ST_T0_SYNC;
                    end else if (evt_pending) begin
                        // 空闲余量：事件事务（速度/力矩广播）
                        tx_type   <= evt_type;
                        tx_arg    <= evt_arg;
                        evt_pending <= 1'b0;
                        tx_start_q  <= 1'b1;
                        st <= ST_EVENT;
                    end
                end
                ST_T0_SYNC: if (tx_done) begin
                    tx_type <= scs_pkg::F_READ_FB;
                    tx_read_id <= poll_i;
                    tx_start_q <= 1'b1;
                    wait_resp <= 1'b1; resp_cnt <= 0; cur_read <= poll_i;
                    st <= ST_T1_READ;
                end
                ST_T1_READ, ST_T2_READ: begin
                    if (rx_frame_done && rx_resp_id == byte'(cur_read + 1)) begin
                        // 回读写寄存器（下方独立 always 块）+ 清掉线位
                        online_bitmap[cur_read] <= 1'b1;
                        wait_resp <= 1'b0;
                        if (st == ST_T1_READ) begin
                            tx_type <= scs_pkg::F_READ_FB;
                            tx_read_id <= poll_j;
                            tx_start_q <= 1'b1;
                            wait_resp <= 1'b1; resp_cnt <= 0; cur_read <= poll_j;
                            st <= ST_T2_READ;
                        end else begin
                            // 轮转推进：每舵机 250Hz
                            poll_i <= (poll_i == 7) ? 3'd0 : poll_i + 2'd2;
                            poll_j <= (poll_j == 7) ? 3'd0 : poll_j + 2'd2;
                            st <= ST_IDLE_SLOT;
                        end
                    end else if (wait_resp && resp_cnt == READ_TIMEOUT_CYC - 1) begin
                        online_bitmap[cur_read] <= 1'b0;  // 掉线
                        wait_resp <= 1'b0;
                        if (st == ST_T1_READ) begin
                            tx_read_id <= poll_j; tx_type <= scs_pkg::F_READ_FB;
                            tx_start_q <= 1'b1;
                            wait_resp <= 1'b1; resp_cnt <= 0; cur_read <= poll_j;
                            st <= ST_T2_READ;
                        end else begin
                            poll_i <= (poll_i == 7) ? 3'd0 : poll_i + 2'd2;
                            poll_j <= (poll_j == 7) ? 3'd0 : poll_j + 2'd2;
                            st <= ST_IDLE_SLOT;
                        end
                    end else if (wait_resp) resp_cnt <= resp_cnt + 1;
                end
                ST_EVENT: if (tx_done) st <= ST_IDLE_SLOT;
            endcase
        end
    end

    // 事件请求（来自 fsm / 寄存器副作用）：单槽覆写（最新优先）
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            evt_pending <= 1'b0;
        end else begin
            if (speed_event) begin
                evt_pending <= 1'b1;
                evt_type    <= scs_pkg::F_BC_SPEED;
                evt_arg     <= speed_raw;
            end
        end
    end
    // 力矩开关事件（fsm 直接驱动 pending——优先级高于速度）
    // （实现见 grasp_fsm：经 evt_torque 口传入；此处用组合覆盖）
    logic        evt_torque_valid;
    logic [7:0]  evt_torque_arg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            evt_torque_valid <= 1'b0; evt_torque_arg <= '0;
        end else if (evt_torque_valid) begin
            evt_pending <= 1'b1;
            evt_type    <= scs_pkg::F_BC_TORQUE;
            evt_arg     <= evt_torque_arg;
            evt_torque_valid <= 1'b0;
        end
    end

    // 回读寄存器
    int unsigned k;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 8; k++) begin
                meas_pos[k] <= '0; meas_load[k] <= '0; meas_temp[k] <= '0;
            end
        end else if (rx_frame_done && rx_resp_id >= 1 && rx_resp_id <= 8) begin
            meas_pos[rx_resp_id - 1]  <= rx_resp_data[15:0];
            meas_load[rx_resp_id - 1] <= rx_resp_data[47:32];
            meas_temp[rx_resp_id - 1] <= rx_resp_data[63:56];
        end
    end

    assign tx_start = tx_start_q;
endmodule
