# Vivado 2020.2: -mode batch -source build.tcl -tclargs NEW_DIR ?generate|synth|impl?
# Extend a private copy of the archived camera BD; never upgrade IP or touch PS.
if {[version -short] ne "2020.2"} {
    error "Unified camera/HIL requires Vivado 2020.2 (camera original: 2020.2_AR75986). No downgrade/upgrade is permitted."
}
if {$argc < 1 || $argc > 2} {error "usage: build.tcl NEW_DIR ?generate|synth|impl?"}
set out [file normalize [lindex $argv 0]]
set stage [expr {$argc == 2 ? [lindex $argv 1] : "generate"}]
if {$stage ni {generate synth impl}} {error "invalid stage: $stage"}
if {[file exists $out]} {error "Refusing existing output directory: $out"}
set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here ../..]]
set camera [file join $root fpga camera_hw]
set live_hz 200703980
# The original script deliberately creates only a new isolated camera project.
set saved_argv $argv
set saved_argc $argc
set argv [list $out]
set argc 1
source [file join $camera scripts create_project.tcl]
set argv $saved_argv
set argc $saved_argc
foreach name {grasp_fsm.sv hand_hil_axi.sv hand_hil_shell.v} {
    add_files -norecurse [file join $here rtl $name]
}
update_compile_order -fileset sources_1
set bd [get_files design_1.bd]
open_bd_design $bd
report_ip_status -file [file join $out ip_status.rpt]
foreach ip [get_ips] {
    if {[get_property IS_LOCKED $ip]} {
        error "Locked IP: $ip. Use the matching 2020.2/AR75986 environment; never auto-upgrade."
    }
}
set ps [get_bd_cells zynq_ultra_ps_e_0]
foreach {key expected} {
    PSU__USE__M_AXI_GP0 1 PSU__MAXIGP0__DATA_WIDTH 128
    PSU__USE__S_AXI_GP3 1 PSU__SAXIGP3__DATA_WIDTH 128
    PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ 200
    PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ 100
} {
    if {[get_property CONFIG.$key $ps] != $expected} {error "Unexpected camera PS: $key"}
}
set bus [get_bd_cells ps8_0_axi_periph]
if {[get_property CONFIG.NUM_MI $bus] != 11} {error "Unexpected camera interconnect"}
# Append one AXI4-Lite destination. The interconnect supplies width/protocol
# conversion from the unchanged 128-bit HPM master. Existing M00..M10 stay wired.
set_property CONFIG.NUM_MI 12 $bus
create_bd_cell -type module -reference hand_hil_shell hil
set_property CONFIG.CLK_HZ $live_hz [get_bd_cells hil]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M11_AXI] [get_bd_intf_pins hil/s_axi]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins hil/clk] [get_bd_pins ps8_0_axi_periph/M11_ACLK]
connect_bd_net [get_bd_pins proc_sys_reset_100M/peripheral_aresetn] [get_bd_pins hil/rst_n] [get_bd_pins ps8_0_axi_periph/M11_ARESETN]
set bank [get_bd_addr_segs -of_objects [get_bd_intf_pins hil/s_axi]]
if {[llength $bank] != 1} {error "Expected a single AHIL register bank"}
# Only this new segment is assigned. Do not auto-assign the camera address map.
assign_bd_address -offset 0xA1000000 -range 4K -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] $bank
validate_bd_design
save_bd_design
write_bd_tcl [file join $out camera_hil_bd.tcl]
# Reuse the original wrapper (external ports unchanged); all products are copies.
generate_target all $bd
update_compile_order -fileset sources_1
if {$stage ne "generate"} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis failed"}
    open_run synth_1
    report_utilization -file [file join $out utilization_synth.rpt]
    close_design
}
if {$stage eq "impl"} {
    # Time the whole preserved camera design at the clocks the current FSBL
    # actually supplies. This changes timing constraints, never PS registers.
    set timing_xdc [file join $out live_clock.xdc]
    set handle [open $timing_xdc w]
    puts $handle {set src [get_pins -hier -filter {REF_PIN_NAME == pl_clk0}]}
    puts $handle {if {[llength $src] != 1} {error "Expected one PS PL0 source"}}
    puts $handle "create_clock -name clk_pl_0 -period [expr {1.0e9/$live_hz}] \$src"
    puts $handle {set src [get_pins -hier -filter {REF_PIN_NAME == pl_clk1}]}
    puts $handle {if {[llength $src] != 1} {error "Expected one PS PL1 source"}}
    # Both reference clocks share the preserved RPLL and 2:1 divisors.
    puts $handle "create_clock -name clk_pl_1 -period [expr {2.0e9/$live_hz}] \$src"
    close $handle
    add_files -fileset constrs_1 -norecurse $timing_xdc
    set_property USED_IN_SYNTHESIS false [get_files $timing_xdc]
    set_property PROCESSING_ORDER LATE [get_files $timing_xdc]
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "implementation failed"}
    open_run impl_1
    report_timing_summary -report_unconstrained -file [file join $out timing_impl.rpt]
    report_drc -file [file join $out drc_impl.rpt]
    report_methodology -file [file join $out methodology_impl.rpt]
    write_hw_platform -fixed -include_bit [file join $out camera_hil.xsa]
}
puts "CAMERA_HIL_DONE stage=$stage output=$out (no hardware access)"
