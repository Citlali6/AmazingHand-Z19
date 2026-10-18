# vivado -mode batch -source fpga/hand_control/build.tcl -tclargs NEW_OUTPUT_DIR ?generate|synth|impl? ?standalone|linux-sd?
# Output directory must not exist. Camera designs/SD/bit/XSA are never opened.
if {$argc < 1} {error "Supply a new isolated absolute output directory"}
set out [file normalize [lindex $argv 0]]
if {[file exists $out]} {error "Refusing existing output directory: $out"}
set stage [expr {$argc>1 ? [lindex $argv 1] : "generate"}]
if {$stage ni {generate synth impl}} {error "stage must be generate, synth or impl"}
set profile [expr {$argc>2 ? [lindex $argv 2] : "standalone"}]
if {$profile ni {standalone linux-sd}} {error "profile must be standalone or linux-sd"}
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
set hpm M_AXI_HPM0_LPD
set hpm_clk maxihpm0_lpd_aclk
set base 0x80000000
if {$profile eq "linux-sd"} {
    # Match the existing camera Linux PS; never execute this XSA's psu_init on it.
    # Live readback: FPD_SLCR.AFI_FS[9:8]=2 (128-bit HPM0), PL0=200703980Hz.
    set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} CONFIG.PSU__USE__M_AXI_GP2 {0} CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACFREQ {27.138} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200}] [get_bd_cells ps]
    set hpm M_AXI_HPM0_FPD
    set hpm_clk maxihpm0_fpd_aclk
    set base 0xA1000000
}
create_bd_cell -type module -reference hand_hil_shell hil
set actual_hz [expr {round(1000000*[get_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ [get_bd_cells ps]])}]
if {$profile eq "linux-sd"} {set actual_hz 200703980}
set_property CONFIG.CLK_HZ $actual_hz [get_bd_cells hil]
puts "HIL effective PS PL0 clock=$actual_hz Hz; watchdog and FSM scaled accordingly"
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
set_property CONFIG.CONST_VAL {1} [get_bd_cells one]
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins ps/$hpm_clk] [get_bd_pins axi/aclk] [get_bd_pins hil/clk] [get_bd_pins reset/slowest_sync_clk]
connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins reset/ext_reset_in]
connect_bd_net [get_bd_pins one/dout] [get_bd_pins reset/dcm_locked]
connect_bd_net [get_bd_pins reset/peripheral_aresetn] [get_bd_pins hil/rst_n] [get_bd_pins axi/aresetn]
connect_bd_intf_net [get_bd_intf_pins ps/$hpm] [get_bd_intf_pins axi/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi/M00_AXI] [get_bd_intf_pins hil/s_axi]
set seg [lindex [get_bd_addr_segs -of_objects [get_bd_intf_pins hil/s_axi]] 0]
assign_bd_address -offset $base -range 4K -target_address_space [get_bd_addr_spaces ps/Data] $seg
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
    if {$profile eq "linux-sd"} {
        # The camera FSBL's measured clock is slightly faster than the nominal
        # PS IP clock. Re-analyse at the live period, without changing PS clocks.
        set live_clock [get_clocks -of_objects [get_pins -hier -filter {REF_PIN_NAME == pl_clk0}]]
        if {[llength $live_clock] != 1} {error "Expected one PS PL0 clock"}
        set clock_source [get_property SOURCE_PINS $live_clock]
        create_clock -name [get_property NAME $live_clock] -period [expr {1.0e9/$actual_hz}] $clock_source
    }
    report_timing_summary -file [file join $out timing_impl.rpt]
    report_drc -file [file join $out drc_impl.rpt]
    write_hw_platform -fixed -include_bit -force [file join $out hand_hil.xsa]
}
puts "HIL_BUILD_DONE stage=$stage profile=$profile base=$base clock_hz=$actual_hz output=$out"
