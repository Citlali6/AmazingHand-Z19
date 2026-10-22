`timescale 1ns/1ps
module tb_hsv;
    logic clk=0, rst_n=0, valid=0, last=0;
    always #5 clk=~clk;
    cv_pkt_pkg::pkt_rgb rgb;
    cv_pkt_pkg::pkt_hsv hsv;
    logic out_valid, out_last;
    logic [47:0] vectors[0:1023];
    integer seen=0, errors=0, sent, hdiff, sdiff;
    cv_rgb_to_hsv dut(.aclk(clk),.aresetn(rst_n),.in(rgb),.s_tvalid(valid),.s_tlast(last),.out(hsv),.m_tvalid(out_valid),.m_tlast(out_last));
    always @(posedge clk) begin
        #1;
        if (rst_n && out_valid) begin
            if (seen>=1024) $fatal(1,"extra output");
            hdiff = integer'(hsv.h)-integer'(vectors[seen][23:16]);
            if(hdiff<0) hdiff=-hdiff;
            if(hdiff>90) hdiff=180-hdiff;
            sdiff=integer'(hsv.s)-integer'(vectors[seen][15:8]);
            if(sdiff<0) sdiff=-sdiff;
            if(hsv.h>179 || hdiff>1 || sdiff>2 || hsv.v!==vectors[seen][7:0] || out_last!==((seen%31)==30)) begin
                if(errors<12) $display("MISMATCH idx=%0d rgb=%h expected=%h got=%h last=%b",seen,vectors[seen][47:24],vectors[seen][23:0],hsv,out_last);
                errors=errors+1;
            end
            seen=seen+1;
        end
    end
    initial begin
        $readmemh("vectors.hex",vectors);
        rgb='0;
        repeat(4) @(negedge clk);
        rst_n=1;
        for(sent=0;sent<1024;sent=sent+1) begin
            @(negedge clk);
            valid=1;rgb=vectors[sent][47:24];last=(sent%31)==30;
            if(sent%5==4) begin
                @(negedge clk);valid=0;last=0;
            end
        end
        @(negedge clk);valid=0;last=0;
        repeat(15) @(negedge clk);
        if(seen!=1024 || errors!=0) $fatal(1,"HSV_FAIL seen=%0d errors=%0d",seen,errors);
        $display("HSV_PASS vectors=%0d H_tolerance=1 S_tolerance=2 V_exact=1 valid_and_tlast_checked=1",seen);
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
