`timescale 1ns/1ps
module tb_hand_hil_axi;
  reg clk=0;always #5 clk=~clk;
  reg rst_n=0;
  reg [11:0] awaddr=0,araddr=0;
  reg [31:0] wdata=0;
  reg [3:0] wstrb=15;
  reg awvalid=0,wvalid=0,arvalid=0;
  wire awready,wready,bvalid,arready,rvalid;
  wire [1:0] bresp,rresp;
  wire [31:0] rdata;
  reg bready=1,rready=1;
  hand_hil_axi #(.WATCHDOG_CYC(50000),.FSM_TICK_CYC(100)) dut(
   .clk(clk),.rst_n(rst_n),.s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
   .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),
   .s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
   .s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),
   .s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready));
  // Explicit AW before W exercises independent channels, never relies on coincidence.
  task wr(input [11:0] addr,input [31:0] data);
    @(negedge clk);awaddr=addr;awvalid=1;
    do @(posedge clk);while(!awready);
    @(negedge clk);awvalid=0;wdata=data;wvalid=1;
    do @(posedge clk);while(!wready);
    @(negedge clk);wvalid=0;
    wait(bvalid);@(negedge clk);repeat(2)@(negedge clk);
  endtask
  task wr_wfirst(input [11:0] addr,input [31:0] data);
    @(negedge clk);wdata=data;wvalid=1;bready=0;
    do @(posedge clk);while(!wready);
    @(negedge clk);wvalid=0;
    repeat(3)@(negedge clk);awaddr=addr;awvalid=1;
    do @(posedge clk);while(!awready);
    @(negedge clk);awvalid=0;wait(bvalid);
    repeat(5)begin @(negedge clk);if(!bvalid)$fatal(1,"B response backpressure");end
    bready=1;repeat(3)@(negedge clk);
  endtask
  task rd(input [11:0] addr,output [31:0] data);
    @(negedge clk);araddr=addr;arvalid=1;
    do @(posedge clk);while(!arready);
    @(negedge clk);arvalid=0;
    wait(rvalid);data=rdata;@(negedge clk);repeat(2)@(negedge clk);
  endtask
  integer seq=0;
  task frame(input integer command,input integer goal,input integer measured,input integer effort,input integer mask);
    seq=seq+1;
    wr('h08,command);wr('h0c,mask);wr('h10,seq);wr('h14,seq);
    for(integer i=0;i<8;i=i+1) begin
      wr('h20+4*i,goal);wr('h40+4*i,measured);wr('h60+4*i,effort);
    end
    wr('h18,1);repeat(12)@(negedge clk);wr('h1c,1);
  endtask
  reg [31:0] v;
  initial begin
    repeat(8)@(negedge clk);rst_n=1;
    rd(0,v);if(v!='h4148494c)$fatal(1,"MAGIC");
    frame(1,3900,2048,0,255);
    rd('h100,v);if(v!=0)$fatal(1,"reset did not reach IDLE");
    rd('h104,v);if(v!=0)$fatal(1,"reset must not enable torque");
    frame(2,2000,2048,0,255);
    rd('h104,v);if(v!=1)$fatal(1,"open torque");
    rd('h120,v);if(v!=2000)$fatal(1,"open target must originate PL");
    frame(3,3000,2000,0,255);
    rd('h100,v);if(v!=1)$fatal(1,"grasp PREGRASP");
    repeat(3500)@(negedge clk);frame(0,999,2100,0,255);
    rd('h100,v);if(v!=2)$fatal(1,"grasp CLOSING");
    rd('h120,v);if(v!=3000)$fatal(1,"tick must not overwrite target");
    frame(0,999,2100,500,255);
    rd('h100,v);if(v!=3)$fatal(1,"feedback load must drive HOLD");
    rd('h120,v);if(v!=2100)$fatal(1,"HOLD snapshot must use feedback");
    frame(5,999,2100,0,255);
    rd('h100,v);if(v!=4)$fatal(1,"release");
    rd('h120,v);if(v!=2000)$fatal(1,"release must use open snapshot");
    repeat(5200)@(negedge clk);frame(0,999,2000,0,255);
    rd('h100,v);if(v!=0)$fatal(1,"release IDLE");
    frame(3,3000,2000,0,255);repeat(3500)@(negedge clk);
    frame(4,999,2200,0,255);rd('h100,v);if(v!=3)$fatal(1,"explicit HOLD");
    frame(6,999,2200,0,255);rd('h104,v);if(v!=0)$fatal(1,"STOP torque");
    frame(3,3800,2200,0,255);rd('h100,v);if(v!=5)$fatal(1,"STOP must latch");
    frame(1,3800,2200,0,255);rd('h104,v);if(v!=0)$fatal(1,"reset old torque");
    frame(2,1800,2200,0,255);repeat(50010)@(negedge clk);wr('h1c,1);
    rd('h108,v);if(!(v&1))$fatal(1,"PL watchdog");
    rd('h104,v);if(v!=0)$fatal(1,"watchdog torque");
    frame(1,3500,2100,0,255);frame(3,3000,2100,0,255);
    frame(0,3000,2150,0,127);rd('h108,v);if(!(v&4))$fatal(1,"offline guard during PREGRASP");
    frame(1,3500,2100,0,255);
    wr('h18,1);repeat(8)@(negedge clk);wr('h1c,1);
    rd('h108,v);if(!(v&8))$fatal(1,"duplicate/replayed seq");
    frame(1,3500,2100,0,255);wr('hf0,1);wr('h1c,1);
    rd('h104,v);if(v!=0)$fatal(1,"out-of-band disconnect STOP");
    // A reset seeds fresh pregrasp positions, with no inherited target/torque.
    frame(1,3900,2300,0,255);frame(3,3000,2300,0,255);
    rd('h120,v);if(v!=2300)$fatal(1,"reset must replace old pregrasp snapshot");
    frame(6,999,2300,0,255);frame(1,3900,2300,0,255);
    frame(4,3900,2300,0,255);rd('h100,v);if(v!=3)$fatal(1,"HOLD from IDLE");
    rd('h120,v);if(v!=2300)$fatal(1,"HOLD target from current feedback");
    wr_wfirst('h20,3200);wr('h1c,1);
    rd('h120,v);if(v!=2300)$fatal(1,"shadow targets must not affect active plan");
    wstrb=8;wr('hf0,1);wstrb=15;wr('h1c,1);
    rd('h108,v);if(v!=0)$fatal(1,"WSTRB must protect STOP low byte");
    @(negedge clk);rready=0;araddr='h100;arvalid=1;
    do @(posedge clk);while(!arready);
    @(negedge clk);arvalid=0;wait(rvalid);v=rdata;
    repeat(5)begin @(negedge clk);if(!rvalid||rdata!=v)$fatal(1,"R response backpressure");end
    rready=1;repeat(3)@(negedge clk);
    $display("PASS HIL AXI: atomic commands, load/hold/release, stop latch/reset, watchdog, offline, replay");
    $finish;
  end
  initial begin #5000000;$fatal(1,"HIL test watchdog");end
endmodule
