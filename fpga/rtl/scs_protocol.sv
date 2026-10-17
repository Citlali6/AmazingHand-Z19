// ============================================================================
// scs_protocol.sv — Feetech SCS 协议帧组包/解析（RTL 对照 Python golden model）
//
// 权威参照：host/app/control/scs_protocol.py（接口契约见
// docs/design/interface.md v0.2 §6）。行为对齐声明：
//   * 帧结构  FF FF ID LEN INS PARAM..CS，LEN=len(PARAM)+2
//   * CS      = ~(ID+LEN+INS+PARAM...) & 0xFF
//   * 时隙帧  T0: SYNC_WRITE(0x83, addr=0x2A, per=2, 8 舵机)  — 32B
//             T1/T2: READ(0x02, addr=0x3A, n=8) 单播          — 8B 请求
//   * 事件帧  广播 WRITE(0x03, addr=0x28/0x2E) 力矩/速度       — 8B
//   * 响应解析 FF FF ID LEN ERR D0..D7 CS（LEN=10）
//
// 注意：SYNC_WRITE 采用 per=2（仅位置）；速度走事件帧（v0.2.1 预算修正）。
// ============================================================================
`default_nettype none

package scs_pkg;
    // 指令码
    localparam byte INS_PING       = 8'h01;
    localparam byte INS_READ       = 8'h02;
    localparam byte INS_WRITE      = 8'h03;
    localparam byte INS_SYNC_WRITE = 8'h83;
    // 常量
    localparam byte BROADCAST_ID   = 8'hFE;
    localparam byte HDR0           = 8'hFF;
    localparam byte HDR1           = 8'hFF;
    // 寄存器地址（SCS0009，见 scs_protocol.Reg）
    localparam byte REG_TORQUE_SW  = 8'h28;
    localparam byte REG_GOAL_POS   = 8'h2A;
    localparam byte REG_RUN_SPEED  = 8'h2E;
    localparam byte REG_FB_ADDR    = 8'h3A;  // pos/speed/load/volt/temp 连读 8B
    localparam byte FB_LEN         = 8'd8;

    // ---- 帧类型（tx 请求编码）----
    typedef enum logic [2:0] {
        F_SYNC_WRITE_POS = 3'd0,  // 32B：8×(id,pos_l,pos_h)
        F_READ_FB        = 3'd1,  // 8B：读指定舵机 0x3A 起 8B
        F_BC_TORQUE      = 3'd2,  // 8B：广播写 0x28，arg=arg_field
        F_BC_SPEED       = 3'd3   // 8B：广播写 0x2E，arg=arg_field（速度 raw 低 8 位）
    } frame_type_e;

    // 校验和：~(ID+LEN+INS+PARAM...) & 0xFF —— 与 Python checksum() 逐位一致
    function automatic byte scs_checksum(byte id, byte len, byte ins, byte q[$]);
        int unsigned s = id + len + ins;
        foreach (q[i]) s += q[i];
        return byte'(~s);
    endfunction
endpackage

// ---------------------------------------------------------------------------
// 帧组包器：一次 start 生成整帧字节流（供 uart 逐字节下发）
// ---------------------------------------------------------------------------
module scs_protocol_tx (
    input  wire clk,
    input  wire rst_n,
    // 请求（脉冲式，start 期间字段保持）
    input  wire        start,
    input  wire scs_pkg::frame_type_e frame_type,
    input  wire [2:0]  read_id,     // F_READ_FB：舵机索引 (0..7)，线上 ID=索引+1
    input  wire [7:0]  arg_field,   // F_BC_*：写值
    input  wire [95:0] pos_raw,     // 8×12bit 位置 raw（ch0 在 LSB），F_SYNC_WRITE_POS
    // 字节流输出（接 half_duplex_uart tx）
    output logic       byte_valid,
    output logic [7:0] byte_data,
    input  wire        byte_ready,
    output logic       done
);
    // 帧长度：SYNC=32, READ=8, BC=8
    function automatic int unsigned frame_len(scs_pkg::frame_type_e t);
        case (t)
            scs_pkg::F_SYNC_WRITE_POS: return 32;
            scs_pkg::F_READ_FB:        return 8;
            default:                   return 8;
        endcase
    endfunction

    int unsigned idx;      // 已发送字节数（含头）
    byte         chk;      // 累加校验（ID+LEN+INS+params，不含头）
    byte         cur;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx <= 0; chk <= '0; byte_valid <= 1'b0; byte_data <= '0; done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start) begin
                idx <= 0; chk <= '0; byte_valid <= 1'b1;
                byte_data <= scs_pkg::HDR0;          // 字节 0：FF
            end else if (byte_valid && byte_ready) begin
                if (idx == frame_len(frame_type) - 1) begin
                    byte_valid <= 1'b0;
                    done       <= 1'b1;              // 最后一字节（CS）已交付
                end else begin
                    idx <= idx + 1;
                    // 逐字节生成
                    case (frame_type)
                        scs_pkg::F_SYNC_WRITE_POS: begin
                            // 0:FF 1:FF 2:FE 3:LEN(28) 4:83 5:2A 6:02
                            // 7+: {id, pos_l, pos_h}×8；末字节 CS
                            unique case (idx)
                                0: byte_data <= scs_pkg::HDR1;
                                1: byte_data <= scs_pkg::BROADCAST_ID;
                                2: begin byte_data <= 8'd28; chk <= byte'(8'd28 + scs_pkg::BROADCAST_ID); end
                                3: begin byte_data <= scs_pkg::INS_SYNC_WRITE; chk <= chk + scs_pkg::INS_SYNC_WRITE; end
                                4: begin byte_data <= scs_pkg::REG_GOAL_POS; chk <= chk + scs_pkg::REG_GOAL_POS; end
                                5: begin byte_data <= 8'd2; chk <= chk + 8'd2; end
                                default: begin
                                    // k = idx-6；字节内偏移 m = k%3
                                    automatic int unsigned k = idx - 6;
                                    if (k < 24) begin
                                        automatic int unsigned servo = k / 3;
                                        automatic byte m = byte'(k % 3);
                                        automatic byte id = byte'(servo + 1);
                                        automatic byte pl = byte'(pos_raw[servo*12 +: 8]);
                                        automatic byte ph = byte'(pos_raw[servo*12 +: 12] >> 8);
                                        cur = (m == 0) ? id : (m == 1) ? pl : ph;
                                        byte_data <= cur;
                                        chk <= chk + cur;
                                    end else begin
                                        byte_data <= ~chk;  // CS
                                    end
                                end
                            endcase
                        end
                        scs_pkg::F_READ_FB: begin
                            // 0:FF 1:FF 2:ID(=read_id+1) 3:04 4:02 5:3A 6:08 7:CS
                            unique case (idx)
                                0: byte_data <= scs_pkg::HDR1;
                                1: byte_data <= {5'd0, read_id} + 8'd1; // 舵机 ID 1..8
                                2: begin byte_data <= 8'h04; chk <= byte'(8'h04 + read_id + 3'd1); end
                                3: begin byte_data <= scs_pkg::INS_READ; chk <= chk + scs_pkg::INS_READ; end
                                4: begin byte_data <= scs_pkg::REG_FB_ADDR; chk <= chk + scs_pkg::REG_FB_ADDR; end
                                5: begin byte_data <= scs_pkg::FB_LEN; chk <= chk + scs_pkg::FB_LEN; end
                                default: byte_data <= ~chk;  // idx=6 → CS
                            endcase
                        end
                        default: begin  // F_BC_TORQUE / F_BC_SPEED：FF FF FE 04 03 ADDR ARG CS
                            unique case (idx)
                                0: byte_data <= scs_pkg::HDR1;
                                1: byte_data <= scs_pkg::BROADCAST_ID;
                                2: begin byte_data <= 8'h04; chk <= byte'(8'h04 + scs_pkg::BROADCAST_ID); end
                                3: begin byte_data <= scs_pkg::INS_WRITE; chk <= chk + scs_pkg::INS_WRITE; end
                                4: begin
                                    byte_data <= (frame_type == scs_pkg::F_BC_TORQUE)
                                                 ? scs_pkg::REG_TORQUE_SW : scs_pkg::REG_RUN_SPEED;
                                    chk <= chk + ((frame_type == scs_pkg::F_BC_TORQUE)
                                                 ? scs_pkg::REG_TORQUE_SW : scs_pkg::REG_RUN_SPEED);
                                end
                                5: begin byte_data <= arg_field; chk <= chk + arg_field; end
                                default: byte_data <= ~chk;  // idx=6 → CS
                            endcase
                        end
                    endcase
                end
            end
        end
    end
endmodule

// ---------------------------------------------------------------------------
// 帧解析器：uart 收到的字节流 → 响应帧事件（READ 响应 14B）
//   帧外垃圾字节自动跳过（与 scs_sim.transact/parse_response 容错一致）
// ---------------------------------------------------------------------------
module scs_protocol_rx (
    input  wire clk,
    input  wire rst_n,
    input  wire        byte_valid,
    input  wire [7:0]  byte_data,
    // 响应帧事件（单周期脉冲 + 载荷）
    output logic       frame_done,     // 完整帧（校验通过）
    output logic       frame_err,      // 校验失败/超长（丢弃该帧）
    output logic [3:0] resp_id,
    output logic [7:0] resp_err,
    output logic [63:0] resp_data      // D0..D7（D0 为 0x3A 位置低字节）
);
    typedef enum logic [2:0] {S_H1, S_H2, S_ID, S_LEN, S_ERR, S_DATA, S_CS} state_e;
    state_e    st;
    byte       len_cnt;   // LEN 字段值
    int unsigned data_idx; // 已收数据字节
    byte       chk;
    logic [63:0] shifter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_H1; frame_done <= 1'b0; frame_err <= 1'b0;
            resp_id <= '0; resp_err <= '0; resp_data <= '0;
            len_cnt <= '0; data_idx <= 0; chk <= '0; shifter <= '0;
        end else begin
            frame_done <= 1'b0; frame_err <= 1'b0;
            if (byte_valid) begin
                unique case (st)
                    S_H1:  if (byte_data == scs_pkg::HDR0) st <= S_H2;
                    S_H2:  st <= (byte_data == scs_pkg::HDR1) ? S_ID : S_H1;
                    S_ID: begin
                        resp_id <= byte_data[3:0];
                        chk     <= byte_data;
                        st      <= S_LEN;
                    end
                    S_LEN: begin
                        if (byte_data < 2 || byte_data > 10) begin
                            st <= S_H1; frame_err <= 1'b1; // 最多 8B 数据，LEN最多10
                        end else begin
                            len_cnt <= byte_data; chk <= chk + byte_data;
                            data_idx <= 0; shifter <= '0;
                            st <= S_ERR;
                        end
                    end
                    S_ERR: begin
                        resp_err <= byte_data; chk <= chk + byte_data;
                        st <= (len_cnt == 2) ? S_CS : S_DATA;
                    end
                    S_DATA: begin
                        shifter[data_idx*8 +: 8] <= byte_data;
                        chk <= chk + byte_data;
                        data_idx <= data_idx + 1;
                        st <= (data_idx + 3 >= len_cnt) ? S_CS : S_DATA;
                    end
                    S_CS: begin
                        if (byte_data == ~chk) begin
                            frame_done <= 1'b1;
                            resp_data  <= shifter;
                        end else begin
                            frame_err <= 1'b1;
                        end
                        st <= S_H1;
                    end
                    default: st <= S_H1;
                endcase
            end
        end
    end
endmodule
