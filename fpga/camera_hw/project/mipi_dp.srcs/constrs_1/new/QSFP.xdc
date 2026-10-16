#set_property PACKAGE_PIN AB34 [get_ports gt_ref_clk_0_clk_p]
#set_property PACKAGE_PIN AB35 [get_ports gt_ref_clk_0_clk_n]

# create_clock -name gtrefclk0 -period 6.4 [get_ports gt_ref_clk_0_clk_p]
# set_clock_groups -group [get_clocks gtrefclk0 -include_generated_clocks] -asynchronous
