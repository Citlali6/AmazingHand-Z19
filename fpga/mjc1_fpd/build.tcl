set root [file normalize [file dirname [info script]]]
set out [file join $root out]
create_project mjc1_fpd [file join $out project_v2] -part xczu19eg-ffvc1760-2-i
add_files -norecurse [list [file join $root src grasp_fsm.sv] [file join $root src mujoco_axi_core.sv] [file join $root src mjc1_axi_lite_top.v]]
update_compile_order -fileset sources_1
create_bd_design mjc1_fpd_bd
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 ps0
source [file join $root src ps_config.tcl]
set_ps_config ps0
# Match the running camera/Linux baseline; do not change AFI width at runtime.
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} CONFIG.PSU__USE__M_AXI_GP1 {0} CONFIG.PSU__USE__M_AXI_GP2 {0} CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} CONFIG.PSU__FPGA_PL0_ENABLE {1} CONFIG.PSU__FPGA_PL1_ENABLE {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200.000} CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {100.000}] [get_bd_cells ps0]
set_property -dict [list CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL {RPLL}] [get_bd_cells ps0]
create_bd_cell -type module -reference mjc1_axi_lite_top mjc1
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ic
set_property -dict [list CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells axi_ic]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps
set_property CONFIG.C_EXT_RESET_HIGH {0} [get_bd_cells rst_ps]
set_property CONFIG.C_AUX_RESET_HIGH {0} [get_bd_cells rst_ps]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero
set_property CONFIG.CONST_VAL {0} [get_bd_cells zero]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
set_property CONFIG.CONST_VAL {1} [get_bd_cells one]
connect_bd_intf_net [get_bd_intf_pins ps0/M_AXI_HPM0_FPD] [get_bd_intf_pins axi_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_ic/M00_AXI] [get_bd_intf_pins mjc1/s_axi]
connect_bd_net [get_bd_pins ps0/pl_clk1] [get_bd_pins ps0/maxihpm0_fpd_aclk] [get_bd_pins axi_ic/ACLK] [get_bd_pins axi_ic/S00_ACLK] [get_bd_pins axi_ic/M00_ACLK] [get_bd_pins mjc1/clk] [get_bd_pins rst_ps/slowest_sync_clk]
connect_bd_net [get_bd_pins ps0/pl_resetn0] [get_bd_pins rst_ps/ext_reset_in]
connect_bd_net [get_bd_pins zero/dout] [get_bd_pins rst_ps/mb_debug_sys_rst]
# Auxiliary reset is active LOW: tie it HIGH to deassert it.
connect_bd_net [get_bd_pins one/dout] [get_bd_pins rst_ps/dcm_locked] [get_bd_pins rst_ps/aux_reset_in]
connect_bd_net [get_bd_pins rst_ps/interconnect_aresetn] [get_bd_pins axi_ic/ARESETN]
connect_bd_net [get_bd_pins rst_ps/peripheral_aresetn] [get_bd_pins axi_ic/S00_ARESETN] [get_bd_pins axi_ic/M00_ARESETN] [get_bd_pins mjc1/rst_n]
assign_bd_address -target_address_space /ps0/Data [get_bd_addr_segs mjc1/s_axi/reg0] -offset 0xA0000000 -range 4K
validate_bd_design
save_bd_design
set bd [get_files */mjc1_fpd_bd.bd]
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files -norecurse $wrapper
set_property top mjc1_fpd_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} { error "Synthesis failed" }
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} { error "Implementation failed" }
open_run impl_1
report_drc -file [file join $out drc.rpt]
report_timing_summary -file [file join $out timing.rpt]
write_hw_platform -fixed -include_bit -force [file join $out mjc1_fpd.xsa]
file copy [file join [get_property DIRECTORY [get_runs impl_1]] mjc1_fpd_bd_wrapper.bit] [file join $out mjc1_fpd.bit]
puts "MJC1_FPD_BUILD_OK"
exit
