// 模块级验证；寄存器profile沿用现有模型，不代表SCS0009实机已核验。
`timescale 1ns/1ps
`default_nettype none
module tb_scs_protocol;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    logic start = 0, ready = 1;
    scs_pkg::frame_type_e kind = scs_pkg::F_READ_FB;
    logic [2:0] read_index = 7;
    wire valid, done;
    wire [7:0] data;
    logic [7:0] captured [64];
    int count = 0;
    scs_protocol_tx tx(.clk(clk), .rst_n(rst_n), .start(start),
        .frame_type(kind), .read_id(read_index), .arg_field(8'd3),
        .pos_raw({8{12'd2048}}), .byte_valid(valid), .byte_data(data),
        .byte_ready(ready), .done(done));
    always @(posedge clk) if (rst_n && valid && ready) begin
        captured[count] <= data;
        count <= count + 1;
    end
    logic rx_valid = 0;
    logic [7:0] rx_data = 0;
    wire frame_done, frame_err;
    wire [3:0] resp_id;
    wire [7:0] resp_err;
    wire [63:0] payload;
    int good = 0, bad = 0;
    scs_protocol_rx rx(.clk(clk), .rst_n(rst_n), .byte_valid(rx_valid),
        .byte_data(rx_data), .frame_done(frame_done), .frame_err(frame_err),
        .resp_id(resp_id), .resp_err(resp_err), .resp_data(payload));
    always @(posedge clk) begin
        if (frame_done) good <= good + 1;
        if (frame_err) bad <= bad + 1;
    end
    task automatic receive(input byte b);
        @(negedge clk); rx_valid = 1; rx_data = b;
        @(negedge clk); rx_valid = 0;
    endtask
    task automatic response(input bit corrupt);
        byte sum;
        sum = 8 + 10;
        receive(8'hFF); receive(8'hFF); receive(8'd8);
        receive(8'd10); receive(8'd0);
        for (int n = 1; n <= 8; n++) begin
            receive(byte'(n)); sum = sum + byte'(n);
        end
        receive(corrupt ? (~sum ^ 8'h01) : ~sum);
        repeat (3) @(negedge clk);
    endtask
    initial begin
        repeat (5) @(negedge clk); rst_n = 1;
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        // 背压期间必须保持当前字节和valid。
        wait (count == 3);
        @(negedge clk); ready = 0;
        begin
            byte held;
            held = data;
            repeat (5) begin
                @(negedge clk);
                assert (valid && data == held) else $fatal(1, "TX stalled byte changed");
            end
        end
        ready = 1;
        @(posedge done); @(negedge clk);
        assert (count == 8) else $fatal(1, "READ must be 8 bytes, got %0d", count);
        assert ({captured[0], captured[1], captured[2], captured[3],
                 captured[4], captured[5], captured[6], captured[7]} ==
                64'hFFFF0804023A08AF) else $fatal(1, "READ #8 frame mismatch");
        receive(8'h42); // 帧外噪声
        response(0);
        assert (good == 1 && bad == 0 && resp_id == 8 && resp_err == 0 &&
                payload == 64'h0807060504030201)
            else $fatal(1, "8-byte payload or checksum decode mismatch");
        response(1);
        assert (good == 1 && bad == 1) else $fatal(1, "Corrupt frame accepted");
        response(0);
        assert (good == 2 && bad == 1) else $fatal(1, "Parser did not recover");
        // 无数据ACK，以及短载荷：数据从低字节开始，不丢首字节。
        receive(8'hFF); receive(8'hFF); receive(8'd1); receive(8'd2);
        receive(8'd0); receive(8'hFC);
        repeat (3) @(negedge clk);
        assert (good == 3 && payload == 0) else $fatal(1, "ACK decode failed");
        receive(8'hFF); receive(8'hFF); receive(8'd1); receive(8'd3);
        receive(8'd0); receive(8'h55); receive(8'hA6);
        repeat (3) @(negedge clk);
        assert (good == 4 && payload == 64'h55) else $fatal(1, "Short payload decode failed");
        receive(8'hFF); receive(8'hFF); receive(8'd1); receive(8'd11);
        repeat (3) @(negedge clk);
        assert (good == 4 && bad == 2) else $fatal(1, "Oversize frame not rejected");
        $display("tb_scs_protocol: ALL PASS");
        $finish;
    end
    initial begin
        #100_000;
        $fatal(1, "protocol watchdog timeout");
    end
endmodule
