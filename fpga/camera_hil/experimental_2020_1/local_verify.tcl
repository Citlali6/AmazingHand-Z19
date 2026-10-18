if {[llength $argv]!=2} {error "usage: local_verify.tcl prepared_root NEW_RESULT"}
lassign $argv prepared out
if {[file exists $out]} {error "refusing existing result"}
file mkdir $out
create_project cdc_local [file join $out project] -part xczu19eg-ffvc1760-2-i
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
set dir [file join $prepared source repo mipi mipi_csi_rx_4lane src mipi-csi-rx]
add_files [glob [file join $dir *.vhd]]
add_files [file join $dir csi_4lane_raw10.v]
add_files [file join $prepared csi_delay_reference.v]
add_files [file join [file dirname [info script]] local_top.v]
set_property top cdc_local_top [current_fileset]
update_compile_order -fileset sources_1
synth_design -top cdc_local_top -part xczu19eg-ffvc1760-2-i
create_clock -name local_pl0 -period 4.982462231192426 [get_ports clk]
create_clock -name local_hs_nominal -period 5.818181818182 [get_ports hs_clk_p]
report_cdc -details -file [file join $out cdc.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
write_checkpoint [file join $out local_synth.dcp]
exit
