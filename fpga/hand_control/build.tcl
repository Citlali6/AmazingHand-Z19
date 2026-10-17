# vivado -mode batch -source fpga/hand_control/build.tcl -tclargs NEW_OUTPUT_DIR ?generate|synth|impl?
# Output directory must not exist. Camera designs/SD/bit/XSA are never opened.
if {$argc < 1} {error "Supply a new isolated absolute output directory"}
set out [file normalize [lindex $argv 0]]
if {[file exists $out]} {error "Refusing existing output directory: $out"}
set stage [expr {$argc>1 ? [lindex $argv 1] : "generate"}]
if {$stage ni {generate synth impl}} {error "stage must be generate, synth or impl"}
set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here ../..]]
source [file join $root fpga/scripts/alinx/project_info.tcl]
create_project hand_hil $out -part $devicePart
set_property target_language Verilog [current_project]
add_files -norecurse [list [file join $root fpga/rtl/grasp_fsm.sv] [file join $here rtl/hand_hil_axi.sv] [file join $here rtl/hand_hil_shell.v]]
update_compile_order -fileset sources_1
create_bd_design hand_hil_bd
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 ps
source [file join $root fpga/scripts/alinx/ps_config.tcl]
set_ps_config ps
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {0} CONFIG.PSU__USE__M_AXI_GP1 {0} CONFIG.PSU__USE__M_AXI_GP2 {1} CONFIG.PSU__FPGA_PL0_ENABLE {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100}] [get_bd_cells ps]
create_bd_cell -type module -reference hand_hil_shell hil
set actual_hz [expr {round(1000000*[get_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ [get_bd_cells ps]])}]
set_property CONFIG.CLK_HZ $actual_hz [get_bd_cells hil]
puts "HIL effective PS PL0 clock=$actual_hz Hz; watchdog and FSM scaled accordingly"
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
set_property CONFIG.CONST_VAL {1} [get_bd_cells one]
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins ps/maxihpm0_lpd_aclk] [get_bd_pins axi/aclk] [get_bd_pins hil/clk] [get_bd_pins reset/slowest_sync_clk]
connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins reset/ext_reset_in]
connect_bd_net [get_bd_pins one/dout] [get_bd_pins reset/dcm_locked]
connect_bd_net [get_bd_pins reset/peripheral_aresetn] [get_bd_pins hil/rst_n] [get_bd_pins axi/aresetn]
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_LPD] [get_bd_intf_pins axi/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi/M00_AXI] [get_bd_intf_pins hil/s_axi]
set seg [lindex [get_bd_addr_segs -of_objects [get_bd_intf_pins hil/s_axi]] 0]
assign_bd_address -offset 0x80000000 -range 4K -target_address_space [get_bd_addr_spaces ps/Data] $seg
validate_bd_design
save_bd_design
generate_target all [get_files hand_hil_bd.bd]
make_wrapper -files [get_files hand_hil_bd.bd] -top
add_files -norecurse [file join $out hand_hil.srcs sources_1 bd hand_hil_bd hdl hand_hil_bd_wrapper.v]
set_property top hand_hil_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1
write_hw_platform -fixed [file join $out hand_hil.xsa]
if {$stage ne "generate"} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis failed"}
    open_run synth_1
    report_utilization -file [file join $out utilization_synth.rpt]
}
if {$stage eq "impl"} {
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "implementation failed"}
    open_run impl_1
    report_timing_summary -file [file join $out timing_impl.rpt]
    report_drc -file [file join $out drc_impl.rpt]
    write_hw_platform -fixed -include_bit -force [file join $out hand_hil.xsa]
}
puts "HIL_BUILD_DONE stage=$stage output=$out"
