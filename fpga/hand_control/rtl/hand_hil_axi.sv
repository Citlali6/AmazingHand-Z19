// HIL-only AXI4-Lite bank. No physical servo pins. Offsets are relative.
// Independent AW/W capture; one outstanding write/read; WSTRB respected.
`default_nettype none
module hand_hil_axi #(
    parameter integer CLK_HZ=100000000,
    parameter integer WATCHDOG_CYC=50000000,
    parameter integer FSM_TICK_CYC=1000000
)(
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET rst_n" *)
    input wire clk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW" *)
    input wire rst_n,
    input wire [11:0] s_axi_awaddr, input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb,
    input wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0] s_axi_bresp, output logic s_axi_bvalid, input wire s_axi_bready,
    input wire [11:0] s_axi_araddr, input wire s_axi_arvalid, output wire s_axi_arready,
    output logic [31:0] s_axi_rdata, output wire [1:0] s_axi_rresp,
    output logic s_axi_rvalid, input wire s_axi_rready
);
    localparam MAGIC=32'h4148494c;
    logic aw_full,w_full;
    logic [11:0] aw_q;
    logic [31:0] w_q;
    logic [3:0] strb_q;
    logic [31:0] shadow[0:63];
    logic [31:0] accepted_seq,feedback_seq,pl_tick,command_count,feedback_count;
    logic [31:0] heartbeat,last_heartbeat,age;
    logic [31:0] fault_bits;
    logic [95:0] target,ctrl_target;
    logic [15:0] pos[8],load[8];
    logic [7:0] online;
    logic cmd_valid,reset_fsm,torque_on;
    logic [7:0] cmd_id,cmd_arg;
    logic [2:0] state;
    logic busy,grasped,timed_out,fsm_fault;
    logic [2:0] pending;
    logic [2:0] seed_pending;
    logic [31:0] snap[0:31];
    wire safe = fault_bits != 0;
    wire torque_enabled = torque_on && !safe;
    wire fsm_rst_n = rst_n && !reset_fsm;
    assign s_axi_awready=!aw_full&&!s_axi_bvalid;
    assign s_axi_wready=!w_full&&!s_axi_bvalid;
    assign s_axi_arready=!s_axi_rvalid;
    assign s_axi_bresp=0;
    assign s_axi_rresp=0;
    grasp_fsm #(.CLK_HZ(CLK_HZ),.TICK_CYC(FSM_TICK_CYC)) u_fsm(
      .clk(clk),.rst_n(fsm_rst_n),.cmd_valid(cmd_valid),.cmd_id(cmd_id),.cmd_arg(cmd_arg),
      .estop(safe),.enable(!safe),.target_pos(target),.torque_lim(32'h66666666),
      .speed_raw(8'd3),.meas_load(load),.meas_pos(pos),.online_bitmap(online),
      .ctrl_target(ctrl_target),.torque_on(torque_on),.speed_event(),
      .evt_torque_valid(),.evt_torque_arg(),.fsm_state(state),.fsm_busy(busy),
      .grasped(grasped),.timeout_flag(timed_out),.fault(fsm_fault));

    always_ff @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        aw_full<=0;w_full<=0;s_axi_bvalid<=0;aw_q<=0;w_q<=0;strb_q<=0;
        s_axi_rvalid<=0;s_axi_rdata<=0;
        accepted_seq<=0;feedback_seq<=0;pl_tick<=0;command_count<=0;feedback_count<=0;
        heartbeat<=0;last_heartbeat<=0;age<=0;fault_bits<=2;
        target<=0;online<=0;cmd_valid<=0;cmd_id<=0;cmd_arg<=0;pending<=0;seed_pending<=0;reset_fsm<=0;
        for(integer i=0;i<64;i=i+1) shadow[i]<=0;
        for(integer i=0;i<32;i=i+1) snap[i]<=0;
        for(integer i=0;i<8;i=i+1) begin pos[i]<=0;load[i]<=0;end
      end else begin
        pl_tick<=pl_tick+1;
        cmd_valid<=0;reset_fsm<=0;
        if(age<WATCHDOG_CYC) age<=age+1;
        else begin fault_bits<=fault_bits|1;pending<=0;end
        // Offline feedback is a latched fault in all enabled states.
        if(!safe && online!=8'hff) begin fault_bits<=fault_bits|4;pending<=0;end
        if(pending!=0 && !safe) begin
          pending<=pending-1;
          if(pending==3) begin cmd_valid<=1;cmd_id<=3;cmd_arg<=0;end
          if(pending==1) begin cmd_valid<=1;cmd_id<=4;cmd_arg<=1;end
        end
        // Reset seeds a fresh pregrasp snapshot without torque. This makes a
        // first grasp/release safe even if the operator has not issued open.
        if(seed_pending!=0 && !safe) begin
          seed_pending<=seed_pending-1;
          if(seed_pending==1) begin cmd_valid<=1;cmd_id<=3;cmd_arg<=0;end
        end
        if(s_axi_awvalid&&s_axi_awready) begin aw_full<=1;aw_q<=s_axi_awaddr;end
        if(s_axi_wvalid&&s_axi_wready) begin w_full<=1;w_q<=s_axi_wdata;strb_q<=s_axi_wstrb;end
        if(s_axi_bvalid&&s_axi_bready) s_axi_bvalid<=0;
        if(aw_full&&w_full&&!s_axi_bvalid) begin
          aw_full<=0;w_full<=0;s_axi_bvalid<=1;
          if(aw_q[1:0]==0 && aw_q<256) begin
            for(integer b=0;b<4;b=b+1)
              if(strb_q[b]) shadow[aw_q[7:2]][8*b+:8]<=w_q[8*b+:8];
          end
          // 0x18 COMMIT=1: atomic copy of the entire request shadow.
          if(aw_q==12'h018 && strb_q==15 && w_q==1) begin
            if(shadow[4]<=accepted_seq || shadow[5]==last_heartbeat) begin
              fault_bits<=fault_bits|8;pending<=0;
            end else begin
              accepted_seq<=shadow[4];feedback_seq<=shadow[4];
              heartbeat<=shadow[5];last_heartbeat<=shadow[5];age<=0;
              feedback_count<=feedback_count+1;
              online<=shadow[3][7:0];
              for(integer i=0;i<8;i=i+1) begin
                pos[i]<={4'd0,shadow[16+i][11:0]};load[i]<=shadow[24+i][15:0];
              end
              // command IDs: tick0 reset1 open2 grasp3 hold4 release5 stop6.
              if(shadow[2]==1 && shadow[3][7:0]==255) begin
                fault_bits<=0;reset_fsm<=1;pending<=0;seed_pending<=3;
                for(integer i=0;i<8;i=i+1) target[i*12+:12]<=shadow[16+i][11:0];
              end else if(shadow[2]==6) begin fault_bits<=fault_bits|2;pending<=0;end
              else if(shadow[3][7:0]!=255) begin fault_bits<=fault_bits|4;pending<=0;end
              else if(shadow[2]>6) begin fault_bits<=fault_bits|16;pending<=0;end
              else if(!safe) begin
                if(shadow[2]!=0) command_count<=command_count+1;
                case(shadow[2])
                  2: if(state==0) begin
                    for(integer i=0;i<8;i=i+1) target[i*12+:12]<=shadow[8+i][11:0];
                    pending<=3;
                  end
                  3: if(state==0) begin
                    for(integer i=0;i<8;i=i+1) target[i*12+:12]<=shadow[8+i][11:0];
                    cmd_valid<=1;cmd_id<=1;cmd_arg<=0;
                  end
                  4: begin
                    cmd_valid<=1;cmd_id<=5;cmd_arg<=0;
                    if(state==0) for(integer i=0;i<8;i=i+1) target[i*12+:12]<=shadow[16+i][11:0];
                  end
                  5: begin cmd_valid<=1;cmd_id<=2;cmd_arg<=0;end
                  default: ;
                endcase
              end
            end
          end
          // 0x1c SNAPSHOT=1: coherent telemetry for PS reads at 0x100.
          if(aw_q==12'h01c && strb_q==15 && w_q==1) begin
            snap[0]<=safe?5:{29'd0,state};snap[1]<={31'd0,torque_enabled};
            snap[2]<=fault_bits;snap[3]<=pl_tick;snap[4]<=accepted_seq;snap[5]<=feedback_seq;
            snap[6]<=command_count;snap[7]<=feedback_count;
            for(integer i=0;i<8;i=i+1) begin
              snap[8+i]<=torque_enabled?{20'd0,ctrl_target[i*12+:12]}:{16'd0,pos[i]};
              snap[16+i]<={16'd0,pos[i]};snap[24+i]<={16'd0,load[i]};
            end
          end
          if(aw_q==12'h0f0 && strb_q[0] && w_q[0]) begin
            fault_bits<=fault_bits|2;pending<=0;
          end
        end
        if(s_axi_rvalid&&s_axi_rready) s_axi_rvalid<=0;
        if(s_axi_arvalid&&s_axi_arready) begin
          s_axi_rvalid<=1;
          if(s_axi_araddr==0) s_axi_rdata<=MAGIC;
          else if(s_axi_araddr==4) s_axi_rdata<=1;
          else if(s_axi_araddr>=256 && s_axi_araddr<384) s_axi_rdata<=snap[(s_axi_araddr-256)>>2];
          else s_axi_rdata<=0;
        end
      end
    end
endmodule
`default_nettype wire
