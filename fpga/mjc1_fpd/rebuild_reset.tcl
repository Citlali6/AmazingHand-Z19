set root [file normalize [file dirname [info script]]]
set out [file join $root out]
open_project [file join $out project_v2 mjc1_fpd.xpr]
open_bd_design [get_files */mjc1_fpd_bd.bd]
set aux [get_bd_pins rst_ps/aux_reset_in]
disconnect_bd_net [get_bd_nets -of_objects $aux] $aux
set_property CONFIG.C_AUX_RESET_HIGH {0} [get_bd_cells rst_ps]
connect_bd_net [get_bd_pins one/dout] $aux
validate_bd_design
if {[get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells rst_ps]] != 0} {error "Aux reset polarity mismatch"}
if {[get_bd_nets -of_objects $aux] ne [get_bd_nets -of_objects [get_bd_pins one/dout]]} {error "Aux reset not deasserted"}
save_bd_design
generate_target all [get_files */mjc1_fpd_bd.bd]
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {error "Synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {error "Implementation failed"}
open_run impl_1
report_drc -file [file join $out drc_r2.rpt]
report_timing_summary -file [file join $out timing_r2.rpt]
write_hw_platform -fixed -include_bit -force [file join $out mjc1_fpd_r2.xsa]
file copy [file join [get_property DIRECTORY [get_runs impl_1]] mjc1_fpd_bd_wrapper.bit] [file join $out mjc1_fpd_r2.bit]
puts "MJC1_FPD_RESET_FIXED_BUILD_OK"
exit
