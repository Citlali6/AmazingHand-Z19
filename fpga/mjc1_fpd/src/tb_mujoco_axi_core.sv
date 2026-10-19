`timescale 1ns/1ps
`default_nettype none

module tb_mujoco_axi_core;
    logic clk=0, rst_n=0;
    always #5 clk=~clk;
    logic [11:0] awaddr=0, araddr=0;
    logic awvalid=0, wvalid=0, bready=0, arvalid=0, rready=0;
    logic [31:0] wdata=0;
    logic [3:0] wstrb=4'hf;
    wire awready,wready,bvalid,arready,rvalid;
    wire [1:0] bresp,rresp;
    wire [31:0] rdata;

    mujoco_axi_core #(.WATCHDOG_CYCLES(256)) dut (
        .clk(clk),.rst_n(rst_n),.s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
        .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),
        .s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
        .s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),
        .s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready)
    );

    task automatic write_reg(input logic [11:0] address, input logic [31:0] value,
                             input logic [3:0] strobe, output logic [1:0] response);
        @(negedge clk); awaddr=address; awvalid=1;
        do @(posedge clk); while (!awready);
        @(negedge clk); awvalid=0; wdata=value; wstrb=strobe; wvalid=1;
        do @(posedge clk); while (!wready);
        @(negedge clk); wvalid=0;
        do @(posedge clk); while (!bvalid);
        response=bresp; @(negedge clk); bready=1;
        @(posedge clk); @(negedge clk); bready=0; wstrb=4'hf;
    endtask

    task automatic read_reg(input logic [11:0] address, output logic [31:0] value,
                            output logic [1:0] response);
        @(negedge clk); araddr=address; arvalid=1;
        do @(posedge clk); while (!arready);
        @(negedge clk); arvalid=0;
        do @(posedge clk); while (!rvalid);
        value=rdata; response=rresp; rready=1;
        @(posedge clk); @(negedge clk); rready=0;
    endtask

    logic [31:0] value;
    logic [1:0] response;
    initial begin
        repeat(5) @(posedge clk); rst_n=1;
        read_reg(12'h000,value,response);
        if (response!=0 || value!=32'h31434a4d) $fatal(1,"MJC1 signature read failed: %h / %b",value,response);
        read_reg(12'h004,value,response);
        if (response!=0 || value!=32'h00010001) $fatal(1,"MJC1 version read failed");
        write_reg(12'h010,32'd1450,4'hf,response);
        if (response!=0) $fatal(1,"full write rejected");
        read_reg(12'h050,value,response);
        if (response!=0 || value[11:0]!=12'd1450) $fatal(1,"FSM target snapshot mismatch: %d",value[11:0]);
        for (int i=0;i<8;i++) write_reg(12'h080+i*4,32'd900,4'hf,response);
        write_reg(12'h0a0,32'd1,4'hf,response);
        if (response!=0) $fatal(1,"feedback commit rejected");
        read_reg(12'h044,value,response);
        if (response!=0 || value!=1) $fatal(1,"feedback sequence not committed");
        // Repeated feedback must keep the watchdog alive over multiple expiry periods.
        for (int sequence_id=3; sequence_id<19; sequence_id+=2) begin
            repeat(160) @(posedge clk);
            write_reg(12'h0a0,sequence_id,4'hf,response);
            if (response!=0 || dut.online_bitmap!=8'hff)
                $fatal(1,"fresh feedback failed to keep channels online");
        end
        repeat(160) @(posedge clk);
        if (dut.online_bitmap!=8'hff) $fatal(1,"watchdog ignored recent feedback");
        repeat(300) @(posedge clk);
        if (dut.online_bitmap!=0) $fatal(1,"watchdog failed to expire stale feedback");
        write_reg(12'h010,32'd1500,4'h1,response);
        if (response!=2'b10) $fatal(1,"partial write must return SLVERR");
        read_reg(12'h0a4,value,response);
        if (response!=2'b10) $fatal(1,"unmapped read must return SLVERR");
        $display("tb_mujoco_axi_core: MJC1_CORE_PASS");
        $finish;
    end
    initial begin #1000000; $fatal(1,"testbench timeout"); end
endmodule
`default_nettype wire
