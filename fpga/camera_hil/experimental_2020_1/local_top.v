module cdc_local_top(input wire clk, reset,
 input wire hs_clk_p,hs_clk_n,input wire [3:0] hs_data_p,hs_data_n,
 input wire sink_ready, output wire valid, output wire [39:0] data);
 wire refclk,io_reset,delay_reset,all_ready,delay_ready;
 csi_delay_reference reference(.clk_pl0(clk),.reset(reset),
 .ready0(delay_ready),.ready1(delay_ready),.ready2(delay_ready),.ready3(delay_ready),
 .refclk(refclk),.io_reset(io_reset),.delay_reset(delay_reset),.all_ready(all_ready));
 csi_4lane_raw10 #(.series("ULTRASCALE_PLUS")) camera(
 .ref_clock_in(clk),.reset(reset),.delay_refclock(refclk),.delay_reset(delay_reset),
 .io_reset(io_reset),.all_ready(all_ready),.delay_ready(delay_ready),
 .mipi_phy_if_clk_hs_n(hs_clk_n),.mipi_phy_if_clk_hs_p(hs_clk_p),
 .mipi_phy_if_clk_lp_n(1'b0),.mipi_phy_if_clk_lp_p(1'b0),
 .mipi_phy_if_data_hs_n(hs_data_n),.mipi_phy_if_data_hs_p(hs_data_p),
 .mipi_phy_if_data_lp_n(4'b0),.mipi_phy_if_data_lp_p(4'b0),
 .m_axis_video_aclk(clk),.m_axis_video_aresetn(!reset),.m_axis_video_tready(sink_ready),
 .m_axis_video_tuser(),.m_axis_video_tlast(),.m_axis_video_tvalid(valid),.m_axis_video_tdata(data));
endmodule
