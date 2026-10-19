`timescale 1ns/1ps
`default_nettype none

// MJC1 simulation-only AXI4-Lite endpoint. It reuses the project grasp FSM,
// but has no physical servo/UART pins.
module mujoco_axi_core #(
    parameter int WATCHDOG_CYCLES = 50_000_000
) (
    input wire clk, input wire rst_n,
    input wire [11:0] s_axi_awaddr, input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb,
    input wire s_axi_wvalid, output wire s_axi_wready,
    output logic [1:0] s_axi_bresp, output logic s_axi_bvalid, input wire s_axi_bready,
    input wire [11:0] s_axi_araddr, input wire s_axi_arvalid, output wire s_axi_arready,
    output logic [31:0] s_axi_rdata, output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid, input wire s_axi_rready
);
    logic [11:0] awaddr_q;
    logic aw_pending, w_pending;
    logic [31:0] wdata_q;
    logic [3:0] wstrb_q;
    logic enable_q, estop_q;
    logic cmd_valid;
    logic [7:0] cmd_id, cmd_arg;
    logic [95:0] target_pos, ctrl_target;
    logic [31:0] torque_lim;
    logic [7:0] speed_raw;
    logic [15:0] meas_load [8], meas_pos [8];
    logic [7:0] online_bitmap;
    logic [2:0] fsm_state;
    logic fsm_busy, grasped, timeout_flag, fault;
    logic torque_on, speed_event, evt_torque_valid;
    logic [7:0] evt_torque_arg;
    logic [31:0] fb_stage [8];
    logic [31:0] fb_sequence, fb_sequence_seen;
    logic [31:0] watchdog;
    wire feedback_commit = aw_pending && w_pending && !s_axi_bvalid &&
        awaddr_q == 12'h0a0 && wstrb_q == 4'hf && wdata_q[0] &&
        fb_sequence_seen != wdata_q;

    assign s_axi_awready = !aw_pending && !s_axi_bvalid;
    assign s_axi_wready  = !w_pending && !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    grasp_fsm u_fsm (
        .clk(clk), .rst_n(rst_n), .cmd_valid(cmd_valid), .cmd_id(cmd_id), .cmd_arg(cmd_arg),
        .estop(estop_q), .enable(enable_q), .target_pos(target_pos), .torque_lim(torque_lim),
        .speed_raw(speed_raw), .meas_load(meas_load), .meas_pos(meas_pos),
        .online_bitmap(online_bitmap), .ctrl_target(ctrl_target), .torque_on(torque_on),
        .speed_event(speed_event), .evt_torque_valid(evt_torque_valid),
        .evt_torque_arg(evt_torque_arg), .fsm_state(fsm_state), .fsm_busy(fsm_busy),
        .grasped(grasped), .timeout_flag(timeout_flag), .fault(fault)
    );

    // AW and W may arrive in either order. A response is issued only after both.
    always_ff @(posedge clk or negedge rst_n) begin : axi_write
        logic [11:0] addr;
        logic [31:0] wd;
        logic [3:0] st;
        if (!rst_n) begin
            aw_pending <= 1'b0; w_pending <= 1'b0; awaddr_q <= '0;
            wdata_q <= '0; wstrb_q <= '0; s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00; enable_q <= 1'b0; estop_q <= 1'b0;
            cmd_valid <= 1'b0; cmd_id <= '0; cmd_arg <= '0;
            target_pos <= '0; torque_lim <= 32'h8888_8888; speed_raw <= 8'd80;
            fb_sequence <= '0; fb_sequence_seen <= '0; watchdog <= '0;
            online_bitmap <= '0;
            for (int i=0;i<8;i++) begin fb_stage[i]<='0; meas_load[i]<='0; meas_pos[i]<='0; end
        end else begin
            cmd_valid <= 1'b0;
            if (s_axi_awvalid && s_axi_awready) begin awaddr_q <= s_axi_awaddr; aw_pending <= 1'b1; end
            if (s_axi_wvalid && s_axi_wready) begin wdata_q <= s_axi_wdata; wstrb_q <= s_axi_wstrb; w_pending <= 1'b1; end
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
            if (aw_pending && w_pending && !s_axi_bvalid) begin
                addr = awaddr_q; wd = wdata_q; st = wstrb_q;
                aw_pending <= 1'b0; w_pending <= 1'b0;
                s_axi_bvalid <= 1'b1; s_axi_bresp <= 2'b00;
                if (addr[1:0] != 2'b00 || st != 4'hF) s_axi_bresp <= 2'b10;
                else if (addr >= 12'h010 && addr <= 12'h02c) target_pos[((addr-12'h010)>>2)*12 +: 12] <= wd[11:0];
                else if (addr == 12'h030) torque_lim <= wd;
                else if (addr == 12'h034) speed_raw <= wd[7:0];
                else if (addr == 12'h008) begin enable_q <= wd[0]; estop_q <= wd[1]; end
                else if (addr == 12'h00c) begin cmd_id <= wd[7:0]; cmd_arg <= wd[15:8]; cmd_valid <= 1'b1; end
                else if (addr >= 12'h080 && addr <= 12'h09c) fb_stage[(addr-12'h080)>>2] <= wd;
                else if (addr == 12'h0a0) begin
                    if (wd[0] && fb_sequence_seen != wd) begin
                        for (int i=0;i<8;i++) begin
                            meas_pos[i] <= {4'b0, fb_stage[i][11:0]};
                            meas_load[i] <= {6'b0, fb_stage[i][21:12]};
                        end
                        fb_sequence <= wd; fb_sequence_seen <= wd; watchdog <= '0;
                        online_bitmap <= 8'hff;
                    end else s_axi_bresp <= 2'b10;
                end else s_axi_bresp <= 2'b10;
            end
            if (online_bitmap != 0 && !feedback_commit) begin
                if (watchdog >= WATCHDOG_CYCLES-1) begin watchdog <= '0; online_bitmap <= '0; end
                else watchdog <= watchdog + 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin : axi_read
        logic [11:0] addr;
        if (!rst_n) begin s_axi_rvalid<=1'b0; s_axi_rdata<='0; s_axi_rresp<=2'b00; end
        else begin
            if (s_axi_rvalid && s_axi_rready) s_axi_rvalid<=1'b0;
            if (s_axi_arvalid && s_axi_arready) begin
                addr=s_axi_araddr; s_axi_rvalid<=1'b1; s_axi_rresp<=2'b00; s_axi_rdata<='0;
                if (addr[1:0] != 0) s_axi_rresp<=2'b10;
                else if (addr==12'h000) s_axi_rdata<=32'h31434a4d; // MJC1
                else if (addr==12'h004) s_axi_rdata<=32'h0001_0001;
                else if (addr==12'h008) s_axi_rdata<={30'b0,estop_q,enable_q};
                else if (addr==12'h040) s_axi_rdata<={25'b0,fault,timeout_flag,grasped,fsm_busy,fsm_state};
                else if (addr==12'h044) s_axi_rdata<=fb_sequence;
                else if (addr>=12'h050 && addr<=12'h06c) s_axi_rdata<={20'b0,ctrl_target[((addr-12'h050)>>2)*12 +: 12]};
                else if (addr>=12'h080 && addr<=12'h09c) s_axi_rdata<=fb_stage[(addr-12'h080)>>2];
                else s_axi_rresp<=2'b10;
            end
        end
    end
endmodule

`default_nettype wire
