set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

## ILA probes from CMAC rx clock domain - async to clk_pl_0, safe for ILA debug
#set_false_path -from [get_clocks rxoutclk_out*] -to [get_cells -hierarchical -filter {NAME =~ *ila_0/inst/PROBE_PIPE*}]
#set_false_path -from [get_clocks txoutclk_out*] -to [get_cells -hierarchical -filter {NAME =~ *ila_0/inst/PROBE_PIPE*}]
