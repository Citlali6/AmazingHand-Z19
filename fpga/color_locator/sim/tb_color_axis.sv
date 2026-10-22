`timescale 1ns/1ps
module tb_color_axis;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    reg [1:0] cfg_color=0;
    reg [7:0] cfg_s=100, cfg_v=80;
    reg [31:0] data_in=0;
    reg valid_in=0, sof_in=0, last_in=0;
    wire ready_in;
    wire [31:0] data_out;
    wire valid_out, sof_out, last_out;
    reg ready_out=0;
    vg_color_axis dut(.aclk(clk),.aresetn(rst_n),.cfg_color(cfg_color),
        .cfg_min_s(cfg_s),.cfg_min_v(cfg_v),.s_axis_tdata(data_in),
        .s_axis_tvalid(valid_in),.s_axis_tready(ready_in),
        .s_axis_tuser(sof_in),.s_axis_tlast(last_in),.m_axis_tdata(data_out),
        .m_axis_tvalid(valid_out),.m_axis_tready(ready_out),
        .m_axis_tuser(sof_out),.m_axis_tlast(last_out));
    reg [33:0] expected [0:4095];
    integer accepted=0, seen=0, cycle=0, stalls=0, held_checks=0;
    integer selected=0, s, v;
    reg enabled=0, match_color, mask;
    reg held=0;
    reg [33:0] held_value;
    function automatic [23:0] palette(input integer index);
        case(index%8)
            0: palette=24'hff0000;
            1: palette=24'h00ff00;
            2: palette=24'h0000ff;
            3: palette=24'hffffff;
            4: palette=24'h000000;
            5: palette=24'hffff00;
            6: palette=24'h800000;
            default: palette=24'h7f7f7f;
        endcase
    endfunction
    always @(negedge clk) begin
        if(!rst_n) begin cycle=0;ready_out=0;end
        else begin
            cycle=cycle+1;
            ready_out=(cycle%173>=100) && (cycle%5!=0);
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            accepted=0;seen=0;held=0;enabled=0;selected=0;
            stalls=0;held_checks=0;
        end else begin
            if(held) begin
                held_checks=held_checks+1;
                if(!valid_out || {sof_out,last_out,data_out}!==held_value)
                    $fatal(1,"output changed while downstream stalled");
            end
            held=valid_out && !ready_out;
            held_value={sof_out,last_out,data_out};
            if(valid_in && !ready_in) stalls=stalls+1;
            if(valid_in && ready_in) begin
                if(sof_in) begin selected=cfg_color;s=cfg_s;v=cfg_v;enabled=1;end
                match_color=(selected==1 && (data_in[23:0]==24'hff0000 || data_in[23:0]==24'h800000)) ||
                            (selected==2 && data_in[23:0]==24'h00ff00) ||
                            (selected==3 && data_in[23:0]==24'h0000ff);
                mask=enabled && match_color &&
                     ((data_in[23:0]==24'h800000 ? 128 : 255)>=v) && 255>=s;
                expected[accepted]={sof_in,last_in,mask,7'b0,data_in[23:0]};
                accepted=accepted+1;
            end
            if(valid_out && ready_out) begin
                if(seen>=accepted || {sof_out,last_out,data_out}!==expected[seen])
                    $fatal(1,"beat %0d expected=%h actual=%h",seen,expected[seen],{sof_out,last_out,data_out});
                seen=seen+1;
            end
            if(dut.fifo_count>16 || dut.outstanding>16)
                $fatal(1,"FIFO credit overflow");
        end
    end
    task automatic send_beat(input integer n, input bit with_sof);
        begin
            @(negedge clk);
            data_in={8'b0,palette(n)};valid_in=1;sof_in=with_sof;
            last_in=n%16==15;
            // Mutate configuration inside a frame: MUST NOT affect it.
            cfg_color=with_sof ? (n/64)%4 : 2'd3;
            cfg_s=with_sof ? 100 : 255;cfg_v=with_sof ? 80 : 255;
            do @(posedge clk); while(!ready_in);
        end
    endtask
    integer n;
    initial begin
        repeat(4) @(negedge clk);rst_n=1;
        // Reset with pixels still in flight; no old output may escape afterward.
        for(n=0;n<8;n=n+1) send_beat(n,n==0);
        @(negedge clk);rst_n=0;valid_in=0;
        repeat(3) @(negedge clk);rst_n=1;
        // Before first SOF pixels pass through, but mask must remain disabled.
        for(n=0;n<16;n=n+1) send_beat(n,0);
        for(n=0;n<2048;n=n+1) begin
            send_beat(n,n%64==0);
            if(n%11==10) begin @(negedge clk);valid_in=0;sof_in=0;last_in=0;end
        end
        @(negedge clk);valid_in=0;sof_in=0;last_in=0;
        wait(seen==accepted);
        repeat(12) @(negedge clk);
        if(seen!=2064 || stalls==0 || held_checks==0 || dut.outstanding!=0)
            $fatal(1,"incomplete test seen=%0d stalls=%0d held=%0d",seen,stalls,held_checks);
        $display("COLOR_AXIS_PASS beats=%0d source_stalls=%0d held_checks=%0d reset=PASS config_snapshot=PASS",seen,stalls,held_checks);
        $finish;
    end
    initial begin #1000000; $fatal(1,"watchdog");end
endmodule
