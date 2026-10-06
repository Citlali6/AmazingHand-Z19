// ============================================================================
// axi_lite_regs.sv — AXI4-Lite 从接口 + 寄存器文件（interface.md v0.2 权威映射）
//
// 控制区（host→PL）: CTRL 0x00 | CMD 0x04 | TARGET_i 0x10+i*4
//                    TORQUE_LIM 0x30 | TIMING 0x34
// 状态区（PL→host）: STATUS 0x80 | FSM_STATE 0x84 | MEAS_i 0x90+i*4
//                    LOAD 0xB0+i*2(半字) | TEMP 0xD0 | ERR_BITMAP 0xE0
//                    TIMESTAMP 0xF0
// CMD 写副作用：cmd_valid 脉冲（fsm 消费）；CTRL.estop 电平直连 fsm。
// 中断：fsm_state 跳变 或 ERR_BITMAP≠0 → irq 置位，读 STATUS 清除。
// ============================================================================
`default_nettype none

module axi_lite_regs #(
    parameter logic [31:0] BASE_ADDR = 32'h4000_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    // AXI4-Lite 从接口
    input  wire [31:0] awaddr,
    input  wire        awvalid,
    output logic       awready,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    input  wire        wvalid,
    output logic       wready,
    output logic [1:0] bresp,
    output logic       bvalid,
    input  wire        bready,
    input  wire [31:0] araddr,
    input  wire        arvalid,
    output logic       arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    // 命令副作用（grasp_fsm）
    output logic        cmd_valid,
    output logic [7:0]  cmd_id,
    output logic [7:0]  cmd_arg,
    // 控制面（fpga 内部）
    output logic [95:0] target_pos,     // host 写入的 8×12bit（→ grasp_fsm.target_pos）
    output logic [31:0] torque_lim,
    output logic [7:0]  speed_raw,
    output logic        enable,
    output logic        estop,
    // 状态面（servo_bus_ctrl / fsm）
    input  wire [2:0]   fsm_state,
    input  wire         fsm_busy,
    input  wire         fsm_grasped,
    input  wire         fsm_timeout,
    input  wire         fsm_fault,
    input  wire [15:0]  meas_pos    [8],
    input  wire [15:0]  meas_load   [8],
    input  wire [7:0]   meas_temp   [8],
    input  wire [7:0]   online_bitmap,
    input  wire [31:0]  loop_timestamp,
    output logic        irq
);
    // ---- 寄存器 ----
    logic [1:0]  ctrl_bits;               // [1]mode [0]enable（estop 单独）
    logic [95:0] target_q;
    logic [31:0] torque_lim_q;
    logic [7:0]  speed_q;
    logic [7:0]  err_bitmap_q;            // 堵转/掉线/超温位图（由 online 与 fsm fault 合成）
    logic        irq_pending;

    assign enable = ctrl_bits[0];
    assign estop  = ctrl_bits[1];         // v0.2 契约：CTRL[2] estop → 位 1 使用说明见 log

    // ERR_BITMAP 合成：bit(3i)=堵转(负载超限历史)——简化：fsm fault→全 1 防御位 + 掉线位
    // （堵转/超温细节位由 slave 回读 error_bits，此处先按掉线合成，联调期扩展）
    logic [7:0] offline_map;
    always_comb begin
        for (int i = 0; i < 8; i++) offline_map[i] = ~online_bitmap[i];
    end
    assign err_bitmap_q = fsm_fault ? 8'hFF : {6'd0, offline_map[1:0]} | {offline_map, 0}; // 占位合成

    // ---- AXI 写通道 ----
    logic        aw_en, w_en;
    logic [31:0] aw_addr_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_en <= 1'b0; w_en <= 1'b0; aw_addr_q <= '0;
            awready <= 1'b0; wready <= 1'b0; bresp <= 2'b00; bvalid <= 1'b0;
        end else begin
            // AW 握手
            if (!awready && awvalid && !aw_en) begin
                awready <= 1'b1; aw_addr_q <= awaddr; aw_en <= 1'b1;
            end else if (bvalid && bready) begin
                aw_en <= 1'b0; awready <= 1'b0;
            end else if (aw_en && wvalid && wready) aw_en <= 1'b0;
            // W 握手
            if (!wready && wvalid && !w_en) begin
                wready <= 1'b1; w_en <= 1'b1;
            end else if (w_en && awvalid && awready) w_en <= 1'b0;
            // B 响应
            if (aw_en && w_en) begin
                bvalid <= 1'b1; bresp <= 2'b00;
            end else if (bvalid && bready) bvalid <= 1'b0;
        end
    end

    // ---- 写解码 + 副作用 ----
    wire [31:0] w_off = aw_addr_q - BASE_ADDR;
    logic wr_en;
    assign wr_en = aw_en && w_en;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_bits <= '0; target_q <= '0; torque_lim_q <= 32'h7777_7777;
            speed_q <= 8'd3; cmd_valid <= 1'b0; cmd_id <= '0; cmd_arg <= '0;
        end else begin
            cmd_valid <= 1'b0;  // 单拍脉冲
            if (wr_en) begin
                unique case (w_off)
                    32'h00: begin
                        ctrl_bits <= wdata[1:0];
                        // bit2 = estop（契约 v0.2 CTRL[2]）
                        ctrl_bits[1] <= wdata[1];
                    end
                    32'h04: begin
                        cmd_valid <= 1'b1; cmd_id <= wdata[7:0]; cmd_arg <= wdata[15:8];
                    end
                    32'h10: if (wstrb[0]) target_q[11:0]   <= wdata[11:0];
                    32'h14: if (wstrb[0]) target_q[23:12]  <= wdata[11:0];
                    32'h18: if (wstrb[0]) target_q[35:24]  <= wdata[11:0];
                    32'h1C: if (wstrb[0]) target_q[47:36]  <= wdata[11:0];
                    32'h20: if (wstrb[0]) target_q[59:48]  <= wdata[11:0];
                    32'h24: if (wstrb[0]) target_q[71:60]  <= wdata[11:0];
                    32'h28: if (wstrb[0]) target_q[83:72]  <= wdata[11:0];
                    32'h2C: if (wstrb[0]) target_q[95:84]  <= wdata[11:0];
                    32'h30: torque_lim_q <= wdata;
                    32'h34: speed_q <= wdata[7:0];
                    default: ;
                endcase
            end
        end
    end
    assign target_pos = target_q;

    // ---- 读通道 ----
    logic        ar_en;
    logic [31:0] ar_addr_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_en <= 1'b0; ar_addr_q <= '0; arready <= 1'b0;
            rvalid <= 1'b0; rresp <= 2'b00; rdata <= '0;
        end else begin
            if (!arready && arvalid && !ar_en) begin
                arready <= 1'b1; ar_addr_q <= araddr; ar_en <= 1'b1;
            end else if (rvalid && rready) begin
                ar_en <= 1'b0; arready <= 1'b0;
            end
            if (ar_en && !rvalid) begin
                rvalid <= 1'b1; rresp <= 2'b00;
                unique case (ar_addr_q - BASE_ADDR)
                    32'h00: rdata <= {30'd0, ctrl_bits};
                    32'h04: rdata <= '0;
                    32'h10: rdata <= {20'd0, target_q[11:0]};
                    32'h14: rdata <= {20'd0, target_q[23:12]};
                    32'h18: rdata <= {20'd0, target_q[35:24]};
                    32'h1C: rdata <= {20'd0, target_q[47:36]};
                    32'h20: rdata <= {20'd0, target_q[59:48]};
                    32'h24: rdata <= {20'd0, target_q[71:60]};
                    32'h28: rdata <= {20'd0, target_q[83:72]};
                    32'h2C: rdata <= {20'd0, target_q[95:84]};
                    32'h30: rdata <= torque_lim_q;
                    32'h34: rdata <= {24'd0, speed_q};
                    32'h80: begin
                        rdata <= {28'd0, fsm_fault, fsm_timeout, fsm_grasped, fsm_busy};
                        irq_pending <= 1'b0;  // 读 STATUS 清中断
                    end
                    32'h84: rdata <= {24'd0, fsm_state};
                    32'h90: rdata <= {16'd0, meas_pos[0]};
                    32'h94: rdata <= {16'd0, meas_pos[1]};
                    32'h98: rdata <= {16'd0, meas_pos[2]};
                    32'h9C: rdata <= {16'd0, meas_pos[3]};
                    32'hA0: rdata <= {16'd0, meas_pos[4]};
                    32'hA4: rdata <= {16'd0, meas_pos[5]};
                    32'hA8: rdata <= {16'd0, meas_pos[6]};
                    32'hAC: rdata <= {16'd0, meas_pos[7]};
                    32'hB0: rdata <= {16'd0, meas_load[0]};
                    32'hB2: rdata <= meas_load[1];
                    32'hB4: rdata <= {16'd0, meas_load[2]};
                    32'hB6: rdata <= meas_load[3];
                    32'hB8: rdata <= {16'd0, meas_load[4]};
                    32'hBA: rdata <= meas_load[5];
                    32'hBC: rdata <= {16'd0, meas_load[6]};
                    32'hBE: rdata <= meas_load[7];
                    32'hD0: rdata <= {24'd0, meas_temp[0]};
                    32'hE0: rdata <= {24'd0, err_bitmap_q};
                    32'hF0: rdata <= loop_timestamp;
                    default: rdata <= 32'hDEAD_0000;
                endcase
            end else if (rvalid && rready) rvalid <= 1'b0;
        end
    end

    // ---- 中断：FSM 状态跳变 或 错误位图非零 ----
    logic [2:0] fsm_state_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_state_d <= 3'd0; irq_pending <= 1'b0; irq <= 1'b0;
        end else begin
            fsm_state_d <= fsm_state;
            if (fsm_state != fsm_state_d || err_bitmap_q != 8'd0) irq_pending <= 1'b1;
            irq <= irq_pending;
        end
    end

endmodule
