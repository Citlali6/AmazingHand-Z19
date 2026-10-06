// ============================================================================
// scs_slave_model.sv — 虚拟 SCS0009 从机（TB 字节级，对照 host/app/control/scs_sim.py）
//
// 简化决策（TB 设计）：本模型工作在**字节级**——直接挂 scs_protocol_tx/rx 的
// 字节流接口，不模拟 UART 位时序。位层（half_duplex_uart 的 1Mbps 定时/过采样）
// 由板端 xsim 或 ILA 实测覆盖。这样 TB 聚焦验证：协议组包/解析、时隙调度、
// 状态机迁移——与 Python golden model 逐行为对照。
//
// 行为对照 scs_sim.VirtualServoBus.transact：
//   PING 单播 → ACK；READ → 8B 反馈帧；WRITE 0x28/0x2A(6B)/0x2E → 寄存器更新；
//   SYNC_WRITE → 逐 id 更新（per 任意，连写视图）；广播 → 不响应；
//   drop_mask[id] → 该舵机静默（掉线注入）；load_inject[i] → 回读负载。
//   pos 动力学：pos 每拍向 goal 逼近 1 步（TB 无需真实电机时间常数）。
// ============================================================================
`default_nettype none

module scs_slave_model (
    input  wire        clk,
    input  wire        rst_n,
    // 主机字节流（来自 scs_protocol_tx）
    input  wire        tx_byte_valid,
    input  wire [7:0]  tx_byte_data,
    // 从机响应字节流（接 scs_protocol_rx）
    output logic       rx_byte_valid,
    output logic [7:0] rx_byte_data,
    // 测试控制
    input  wire [15:0] load_inject [8],  // 负载注入（模拟夹持阻力）
    input  wire [7:0]  drop_mask         // 掉线注入（bit0..7 = 舵机1..8）
);
    // ---- 内部状态（8 舵机）----
    logic [11:0] goal    [8];
    logic [11:0] pos     [8];
    logic [7:0]  torque  [8];
    logic [15:0] load_q  [8];
    logic [7:0]  temp_q  [8];

    // ---- 接收解析（从机视角帧解析）----
    typedef enum logic [2:0] {W_H1, W_H2, W_ID, W_LEN, W_INS, W_PADDR, W_PDLEN, W_PARAMS, W_CS} wst_e;
    wst_e wst;
    logic [7:0] w_id, w_len, w_ins, w_addr, w_dlen;
    int unsigned p_idx;
    logic [7:0] param_q [64];
    byte chk;
    logic       resp_pending;
    logic [7:0] resp_q [16];
    int unsigned resp_len, resp_i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wst <= W_H1; p_idx <= 0; chk <= '0;
            rx_byte_valid <= 1'b0; rx_byte_data <= '0;
            resp_pending <= 1'b0; resp_len <= 0; resp_i <= 0;
            for (int i = 0; i < 8; i++) begin
                goal[i] <= 12'd2048; pos[i] <= 12'd2048;
                torque[i] <= '0; load_q[i] <= '0; temp_q[i] <= 8'd25;
            end
        end else begin
            rx_byte_valid <= 1'b0;
            // 响应字节流泵出
            if (resp_pending) begin
                if (resp_i < resp_len) begin
                    rx_byte_valid <= 1'b1;
                    rx_byte_data  <= resp_q[resp_i];
                    resp_i <= resp_i + 1;
                end else begin
                    resp_pending <= 1'b0; resp_i <= 0;
                end
            end
            // pos 动力学：向 goal 逼近
            for (int i = 0; i < 8; i++) begin
                if (torque[i] != 0 && pos[i] != goal[i])
                    pos[i] <= pos[i] + ((goal[i] > pos[i]) ? 1 : -1);
            end

            // 主机字节流解析
            if (tx_byte_valid) begin
                unique case (wst)
                    W_H1:  wst <= (tx_byte_data == 8'hFF) ? W_H2 : W_H1;
                    W_H2:  wst <= (tx_byte_data == 8'hFF) ? W_ID : W_H1;
                    W_ID:  begin w_id <= tx_byte_data; chk <= tx_byte_data; wst <= W_LEN; end
                    W_LEN: begin w_len <= tx_byte_data; chk <= chk + tx_byte_data; wst <= W_INS; end
                    W_INS: begin w_ins <= tx_byte_data; chk <= chk + tx_byte_data; p_idx <= 0; wst <= W_PARAMS; end
                    W_PARAMS: begin
                        if (p_idx == 0 && w_ins == 8'h02) begin
                            w_addr <= tx_byte_data;            // READ: 参数[0]=addr
                        end
                        if (p_idx == 0 && (w_ins == 8'h03 || w_ins == 8'h83)) begin
                            w_addr <= tx_byte_data;            // WRITE/SYNC: 参数[0]=addr
                        end else if (p_idx == 1 && w_ins == 8'h83) begin
                            w_dlen <= tx_byte_data;            // SYNC: 参数[1]=每舵机长度
                        end
                        param_q[p_idx] <= tx_byte_data;
                        chk <= chk + tx_byte_data;
                        // 参数个数 = LEN-2；收满转 CS
                        if (p_idx == w_len - 3) wst <= W_CS;
                        p_idx <= p_idx + 1;
                    end
                    W_CS: begin
                        wst <= W_H1;
                        if (tx_byte_data == ~chk) begin
                            // 校验通过 → 执行
                            automatic logic broadcast = (w_id == 8'hFE);
                            automatic logic dropped = 1'b0;
                            automatic logic [3:0] uid = w_id[3:0];
                            if (!broadcast) dropped = drop_mask[uid - 1];
                            if (!dropped) begin
                                unique case (w_ins)
                                    8'h02: begin  // READ addr len → 响应
                                        if (!broadcast) begin
                                            // 组响应帧：FF FF ID 0A ERR D0..D7 CS
                                            resp_q[0] <= 8'hFF; resp_q[1] <= 8'hFF;
                                            resp_q[2] <= w_id; resp_q[3] <= 8'h0A;
                                            resp_q[4] <= 8'h00;
                                            resp_q[5] <= pos[uid-1][7:0];
                                            resp_q[6] <= {4'd0, pos[uid-1][11:8]};
                                            resp_q[7] <= 8'd0; resp_q[8] <= 8'd0;
                                            resp_q[9] <= load_q[uid-1][7:0];
                                            resp_q[10] <= load_q[uid-1][15:8];
                                            resp_q[11] <= 8'd74;
                                            resp_q[12] <= temp_q[uid-1];
                                            resp_q[13] <= ~(w_id + 8'h0A + 8'h00
                                                          + pos[uid-1][7:0] + {4'd0, pos[uid-1][11:8]}
                                                          + load_q[uid-1][7:0] + load_q[uid-1][15:8]
                                                          + 8'd74 + temp_q[uid-1]);
                                            resp_len <= 14; resp_i <= 0; resp_pending <= 1'b1;
                                        end
                                    end
                                    8'h03: begin  // WRITE（单播/广播）
                                        if (w_addr == 8'h28) torque[uid-1] <= param_q[1];
                                        else if (w_addr == 8'h2A) begin
                                            goal[uid-1] <= {param_q[2][3:0], param_q[1]};
                                            if (w_len >= 7) goal[uid-1] <= {param_q[2][3:0], param_q[1]};
                                        end
                                        else if (w_addr == 8'h2E) ;
                                        // 广播 WRITE 不响应；单播 ACK（status_return_level=2）
                                        if (!broadcast) begin
                                            resp_q[0] <= 8'hFF; resp_q[1] <= 8'hFF;
                                            resp_q[2] <= w_id; resp_q[3] <= 8'h02;
                                            resp_q[4] <= 8'h00;
                                            resp_q[5] <= ~(w_id + 8'h02 + 8'h00);
                                            resp_len <= 6; resp_i <= 0; resp_pending <= 1'b1;
                                        end
                                    end
                                    8'h83: begin  // SYNC_WRITE：逐 (id, data) 更新
                                        for (int s = 0; s < 8; s++) begin
                                            automatic int unsigned base = 2 + s * (w_dlen + 1);
                                            if (base + w_dlen < 64 && param_q[base] != 0) begin
                                                automatic logic [3:0] sid = param_q[base][3:0];
                                                if (w_addr == 8'h2A && w_dlen == 2)
                                                    goal[sid-1] <= {param_q[base+2][3:0], param_q[base+1]};
                                                else if (w_addr == 8'h2A && w_dlen == 6)
                                                    goal[sid-1] <= {param_q[base+2][3:0], param_q[base+1]};
                                            end
                                        end
                                    end
                                    default: ;
                                endcase
                            end
                        end
                    end
                    default: wst <= W_H1;
                endcase
            end
        end
    end

    // 负载注入
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) for (int i = 0; i < 8; i++) load_q[i] <= '0;
        else        for (int i = 0; i < 8; i++) load_q[i] <= load_inject[i];
    end
endmodule
