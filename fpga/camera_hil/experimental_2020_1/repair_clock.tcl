# Preserve the original experiment and create a separate implementation run.
# -source repair_clock.tcl -tclargs ORIGINAL_BUILD NEW_REPORT_DIR ?diagnose|impl?
# No reset_runs, IP edits, constraint overwrites, PS init or hardware access.
if {[version -short] ne "2020.1" || $argc < 2 || $argc > 3} {error "Requires 2020.1 and ORIGINAL_BUILD NEW_REPORT_DIR ?diagnose|impl?"}
set build [file normalize [lindex $argv 0]]
set result [file normalize [lindex $argv 1]]
set stage [expr {$argc == 3 ? [lindex $argv 2] : "diagnose"}]
if {$stage ni {diagnose impl}} {error "Expected diagnose or impl"}
if {[file exists $result]} {error "Refusing existing result directory"}
file mkdir $result
file copy [file normalize [info script]] [file join $result repair_clock_executed.tcl]
open_project [file join $build vivado mipi_dp.xpr]
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Successful original synthesis required"}
# Select a fresh constraint set before opening the synthesized netlist, so the
# failed attempt's live_clock.xdc is never applied during source discovery.
set constrset [expr {$stage eq "diagnose" ? "clock_diagnose" : "live_clock_fixed"}]
set run [expr {$stage eq "diagnose" ? "diagnose_liveclock" : "impl_liveclock"}]
create_fileset -constrset $constrset
foreach name {system.xdc mipi.xdc QSFP.xdc ddr4_set.xdc mipi2.xdc} {
    add_files -fileset $constrset -norecurse [file join $build source mipi_dp.srcs constrs_1 new $name]
}
create_run $run -parent_run synth_1 -flow {Vivado Implementation 2020} -strategy {Vivado Implementation Defaults} -constrset $constrset
current_run -implementation [get_runs $run]
open_run synth_1
set xdc [file join $result live_clock_single_source.xdc]
set f [open $xdc w]
foreach index {0 1} {
    set period [expr {1.0e9 * (1 + $index) / 200703980}]
    set clk [get_clocks clk_pl_$index]
    set sources [get_property SOURCE_PINS $clk]
    # Read the original PS clock, before adding the new constraint set.
    if {[llength $clk] != 1 || [llength $sources] != 1} {error "Expected original single-source PS clock $index: $sources"}
    puts "ORIGINAL_CLOCK_SOURCE clk_pl_$index $sources"
    puts $f "create_clock -name clk_pl_$index -period $period \[get_pins \{$sources\}\]"
}
close $f
close_design
add_files -fileset $constrset -norecurse $xdc
set_property USED_IN_SYNTHESIS false [get_files $xdc]
set_property PROCESSING_ORDER LATE [get_files $xdc]
if {$stage eq "impl"} {
    launch_runs $run -to_step write_bitstream -jobs 4
    wait_on_run $run
    if {[get_property PROGRESS [get_runs $run]] ne "100%"} {error "Corrected-clock implementation failed"}
    open_run $run
} else {
    open_checkpoint [file join $build vivado mipi_dp.runs impl_1 design_1_wrapper_routed.dcp]
    read_xdc $xdc
}
report_clocks -file [file join $result clocks_impl.rpt]
set f [open [file join $result clock_sources.txt] w]
foreach index {0 1} {
    set clk [get_clocks clk_pl_$index]
    if {[llength $clk] != 1 || [llength [get_property SOURCE_PINS $clk]] != 1} {error "Final PL clock must have one source"}
    puts $f "clk_pl_$index\t[get_property PERIOD $clk]\t[get_property SOURCE_PINS $clk]"
}
close $f
report_timing_summary -report_unconstrained -file [file join $result timing_impl.rpt]
report_drc -file [file join $result drc_impl.rpt]
report_methodology -file [file join $result methodology_impl.rpt]
if {$stage eq "impl"} {
    write_hw_platform -fixed -include_bit [file join $result camera_hil.xsa]
    set f [open [file join $result implementation.json] w]
    puts $f "\{\"build\":\"$build\",\"implementation_run\":\"impl_liveclock\",\"repair\":\"single-source live clocks; no IP or PS edits\"\}"
} else {
    set f [open [file join $result diagnosis.json] w]
    puts $f "\{\"build\":\"$build\",\"stage\":\"routed DCP reanalysis only\",\"implementation_rerun\":false,\"corrected_bit_created\":false\}"
}
close $f
puts "REPAIRED_CLOCK_DONE stage=$stage; no board validation"
