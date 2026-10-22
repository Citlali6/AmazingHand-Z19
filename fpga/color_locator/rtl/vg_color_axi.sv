// Color diagnostic endpoint; AXI port attributes follow the verified FPD endpoint.
module vg_color_axi (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET rst_n" *)
    input wire clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW" *)
    input wire rst_n,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWADDR" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12, HAS_BURST 0, HAS_LOCK 0, HAS_CACHE 0, HAS_PROT 0, HAS_QOS 0, HAS_REGION 0" *)
    input wire [11:0] s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWVALID" *) input wire s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWREADY" *) output wire s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WDATA" *) input wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WSTRB" *) input wire [3:0] s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WVALID" *) input wire s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WREADY" *) output wire s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BRESP" *) output wire [1:0] s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BVALID" *) output wire s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BREADY" *) input wire s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARADDR" *) input wire [11:0] s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARVALID" *) input wire s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARREADY" *) output wire s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RDATA" *) output wire [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RRESP" *) output wire [1:0] s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RVALID" *) output wire s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RREADY" *) input wire s_axi_rready
);
    reg aw_hold, w_hold, b_valid, r_valid;
    reg [11:0] aw_address;
    reg [31:0] w_data, r_data;
    reg [3:0] w_strb;
    reg soft_reset, bus_error;
    reg [31:0] config_reg, frame_id;
    reg [15:0] width_reg, height_reg;
    reg pixel_pending;
    reg [31:0] pixel_word;
    reg [31:0] input_count, output_count, mask_count;
    reg [15:0] in_x, in_y, out_x, out_y;
    reg [15:0] xmin, xmax, ymin, ymax;
    reg frame_done, stream_error;
    wire [31:0] total_pixels = {16'b0,width_reg} * {16'b0,height_reg};
    wire core_resetn = rst_n && !soft_reset;
    wire core_ready, core_valid, core_sof, core_eol;
    wire [31:0] core_data;
    wire ar_take = s_axi_arvalid && s_axi_arready;
    wire pop_pixel = ar_take && s_axi_araddr == 12'h024 && core_valid;
    wire push_pixel = pixel_pending && core_ready;
    wire can_write_pixel = core_resetn && !pixel_pending && core_ready &&
                           input_count < total_pixels && !frame_done;
    wire [23:0] rgb = core_data[23:0];
    // Highlighting is also PL logic. PS only encodes the returned RGB as JPEG.
    wire [23:0] display_rgb = (config_reg[1:0]==0 || core_data[31]) ? rgb :
                             {2'b0,rgb[23:18],2'b0,rgb[15:10],2'b0,rgb[7:2]};
    vg_color_axis color_pipeline (
        .aclk(clk), .aresetn(core_resetn), .cfg_color(config_reg[1:0]),
        .cfg_min_s(config_reg[15:8]), .cfg_min_v(config_reg[23:16]),
        .s_axis_tdata(pixel_word), .s_axis_tvalid(pixel_pending), .s_axis_tready(core_ready),
        .s_axis_tuser(in_x==0 && in_y==0), .s_axis_tlast(in_x==width_reg-1),
        .m_axis_tdata(core_data), .m_axis_tvalid(core_valid), .m_axis_tready(pop_pixel),
        .m_axis_tuser(core_sof), .m_axis_tlast(core_eol)
    );
    assign s_axi_awready = !aw_hold && !b_valid;
    assign s_axi_wready = !w_hold && !b_valid;
    assign s_axi_bvalid = b_valid;
    assign s_axi_bresp = 2'b00;
    assign s_axi_arready = !r_valid;
    assign s_axi_rvalid = r_valid;
    assign s_axi_rdata = r_data;
    assign s_axi_rresp = 2'b00;
    wire config_idle = input_count==0 && output_count==0 && !pixel_pending;

    // Every AXI access terminates. Bad/empty accesses set a sticky diagnostic
    // bit instead of stalling a CPU MMIO transaction indefinitely.
    always @(posedge clk) begin
        if (!rst_n) begin
            aw_hold<=0; w_hold<=0; b_valid<=0; r_valid<=0; r_data<=0;
            aw_address<=0; w_data<=0; w_strb<=0;
            soft_reset<=0; bus_error<=0; pixel_pending<=0; pixel_word<=0;
            config_reg<=32'h00506401; width_reg<=1280; height_reg<=720; frame_id<=0;
        end else begin
            soft_reset<=0;
            if (b_valid && s_axi_bready) b_valid<=0;
            if (r_valid && s_axi_rready) r_valid<=0;
            if (s_axi_awvalid && s_axi_awready) begin aw_hold<=1;aw_address<=s_axi_awaddr;end
            if (s_axi_wvalid && s_axi_wready) begin w_hold<=1;w_data<=s_axi_wdata;w_strb<=s_axi_wstrb;end
            if (push_pixel) pixel_pending<=0;
            if (soft_reset) begin pixel_pending<=0;bus_error<=0;end
            if (aw_hold && w_hold && !b_valid) begin
                aw_hold<=0;w_hold<=0;b_valid<=1;
                if (w_strb!=4'hf || aw_address[1:0]!=0) bus_error<=1;
                else case (aw_address)
                    12'h008: if (w_data==1) soft_reset<=1; else bus_error<=1;
                    12'h00c: if(config_idle) config_reg<=w_data; else bus_error<=1;
                    12'h010: if(config_idle && w_data>=1 && w_data<=1280) width_reg<=w_data[15:0]; else bus_error<=1;
                    12'h014: if(config_idle && w_data>=1 && w_data<=720) height_reg<=w_data[15:0]; else bus_error<=1;
                    12'h020: if(can_write_pixel) begin pixel_word<=w_data;pixel_pending<=1;end else bus_error<=1;
                    12'h040: if(config_idle) frame_id<=w_data; else bus_error<=1;
                    default: bus_error<=1;
                endcase
            end
            if(ar_take) begin
                r_valid<=1;
                case(s_axi_araddr)
                    12'h000:r_data<=32'h31524c43; // CLR1
                    12'h004:r_data<=32'h00010001;
                    12'h00c:r_data<=config_reg;
                    12'h010:r_data<={16'b0,width_reg};
                    12'h014:r_data<={16'b0,height_reg};
                    12'h018:r_data<={28'b0,frame_done,(bus_error||stream_error),core_valid,can_write_pixel};
                    12'h01c:r_data<=input_count;
                    12'h024:begin
                        r_data<=core_valid ? {core_data[31],7'b0,display_rgb} : 0;
                        if(!core_valid) bus_error<=1;
                    end
                    12'h028:r_data<=output_count;
                    12'h02c:r_data<=mask_count;
                    12'h030:r_data<=mask_count==0 ? 0 : {16'b0,xmin};
                    12'h034:r_data<=mask_count==0 ? 0 : {16'b0,xmax};
                    12'h038:r_data<=mask_count==0 ? 0 : {16'b0,ymin};
                    12'h03c:r_data<=mask_count==0 ? 0 : {16'b0,ymax};
                    12'h040:r_data<=frame_id;
                    default:begin r_data<=0;bus_error<=1;end
                endcase
            end
        end
    end
    always @(posedge clk) begin
        if(!core_resetn) begin
            input_count<=0;output_count<=0;mask_count<=0;
            in_x<=0;in_y<=0;out_x<=0;out_y<=0;
            xmin<=16'hffff;xmax<=0;ymin<=16'hffff;ymax<=0;
            frame_done<=0;stream_error<=0;
        end else begin
            if(push_pixel) begin
                input_count<=input_count+1'b1;
                if(in_x==width_reg-1) begin in_x<=0;in_y<=in_y+1'b1;end
                else in_x<=in_x+1'b1;
                if(input_count>=total_pixels) stream_error<=1;
            end
            if(pop_pixel) begin
                output_count<=output_count+1'b1;
                if(core_sof !== (out_x==0 && out_y==0) || core_eol !== (out_x==width_reg-1)) stream_error<=1;
                if(core_data[31]) begin
                    mask_count<=mask_count+1'b1;
                    if(out_x<xmin) xmin<=out_x;
                    if(out_x>xmax) xmax<=out_x;
                    if(out_y<ymin) ymin<=out_y;
                    if(out_y>ymax) ymax<=out_y;
                end
                if(out_x==width_reg-1) begin out_x<=0;out_y<=out_y+1'b1;end
                else out_x<=out_x+1'b1;
                if(output_count==total_pixels-1) frame_done<=1;
                if(output_count>=total_pixels) stream_error<=1;
            end
        end
    end
endmodule
