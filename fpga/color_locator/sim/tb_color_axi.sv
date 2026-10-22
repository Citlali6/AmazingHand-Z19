`timescale 1ns/1ps
module tb_color_axi;
 reg clk=0,rst_n=0;always #5 clk=~clk;
 reg[11:0] awaddr=0,araddr=0;reg awvalid=0,wvalid=0,bready=1,arvalid=0,rready=0;
 reg[31:0] wdata=0;reg[3:0] wstrb=15;
 wire awready,wready,bvalid,arready,rvalid;wire[1:0]bresp,rresp;wire[31:0]rdata;
 vg_color_axi dut(.clk(clk),.rst_n(rst_n),.s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
 .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
 .s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready));
 task automatic wr(input[11:0]a,input[31:0]d);
 begin
  @(negedge clk);awaddr=a;awvalid=1;
  do @(posedge clk);while(!awready);
  @(negedge clk);awvalid=0;
  repeat(2) @(negedge clk);wdata=d;wvalid=1;
  do @(posedge clk);while(!wready);
  @(negedge clk);wvalid=0;
  do @(posedge clk);while(!bvalid);
  if(bresp!=0)$fatal(1,"BRESP");
 end endtask
 task automatic rd(input[11:0]a,output[31:0]d);
 reg[31:0] held;
 begin
  @(negedge clk);araddr=a;arvalid=1;
  do @(posedge clk);while(!arready);
  @(negedge clk);arvalid=0;
  do @(posedge clk);while(!rvalid);
  held=rdata;
  repeat(3) begin @(posedge clk);if(!rvalid||rdata!==held)$fatal(1,"R stall changed");end
  d=held;
  @(negedge clk);rready=1;
  @(posedge clk);
  @(negedge clk);rready=0;
 end endtask
 function automatic [23:0] pix(input integer n);
 case(n%8)
  0,3:pix=24'hff0000;
  1,5:pix=24'h00ff00;
  2,6:pix=24'h0000ff;
  default:pix=24'hffffff;
 endcase endfunction
 integer color,n,expected_hit,count,tests=0;
 reg[31:0] v,s;reg[23:0]rgb,dim;
 initial begin
 repeat(4)@(negedge clk);rst_n=1;
 rd(0,v);if(v!==32'h31524c43)$fatal(1,"ID");
 for(color=0;color<4;color=color+1)begin
  wr('h008,1);wr('h010,8);wr('h014,2);wr('h00c,32'h00506400|color);wr('h040,color+100);
  count=0;
  for(n=0;n<16;n=n+1)begin
   rd('h018,s);if(!s[0])$fatal(1,"not ready");
   wr('h020,{8'b0,pix(n)});
   rd('h018,s);while(!s[1])rd('h018,s);
   rd('h024,v);rgb=pix(n);
   expected_hit=(color==1&&rgb==24'hff0000)||(color==2&&rgb==24'h00ff00)||(color==3&&rgb==24'h0000ff);
   dim=(color==0||expected_hit)?rgb:{2'b0,rgb[23:18],2'b0,rgb[15:10],2'b0,rgb[7:2]};
   if(v[31]!==expected_hit[0]||v[23:0]!==dim)$fatal(1,"pixel c%0d n%0d got%h",color,n,v);
   count=count+expected_hit;tests=tests+1;
  end
  rd('h018,s);if(!s[3]||s[2])$fatal(1,"frame status %h",s);
  rd('h01c,v);if(v!=16)$fatal(1,"input count");
  rd('h028,v);if(v!=16)$fatal(1,"output count");
  rd('h02c,v);if(v!=count)$fatal(1,"mask count");
  rd('h040,v);if(v!=color+100)$fatal(1,"sequence");
  rd('h030,v);if(v!=(color==0?0:color-1))$fatal(1,"xmin c%0d got%0d",color,v);
  rd('h034,v);if(v!=(color==0?0:color==1?3:color==2?5:6))$fatal(1,"xmax");
  rd('h038,v);if(v!=0)$fatal(1,"ymin");
  rd('h03c,v);if(v!=(color==0?0:1))$fatal(1,"ymax");
 end
 // Empty reads must return without hanging, report the error, then recover.
 rd('h024,v);rd('h018,s);if(!s[2])$fatal(1,"empty read not diagnosed");
 wr('h008,1);rd('h018,s);if(s[2]||s[3])$fatal(1,"soft reset failed");
 // A partial configuration write is rejected, preserving the previous value.
 wstrb=1;wr('h010,100);wstrb=15;rd('h010,v);if(v!=8)$fatal(1,"partial write mutated width");
 rd('h018,s);if(!s[2])$fatal(1,"partial write not diagnosed");
 wr('h008,1);rd('h018,s);if(s[2])$fatal(1,"reset recovery");
 $display("COLOR_AXI_PASS pixels=%0d colors=4 decoupled_AW_W=PASS read_stalls=PASS stats=PASS error_recovery=PASS",tests);
 $finish;
 end
 initial begin #1000000;$fatal(1,"AXI watchdog");end
endmodule
