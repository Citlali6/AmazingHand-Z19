# Read-only inspection. Never writes or reuses the old implementation outputs.
if {[llength $argv] < 2 || [llength $argv] > 3} {error "usage: inspect_dcp.tcl routed.dcp NEW_RESULT ?netlist_hook?"}
lassign $argv dcp out hook
if {[file exists $out]} {error "result already exists"}
file mkdir $out
open_checkpoint $dcp
set f [open [file join $out primitives.txt] w]
foreach c [get_cells -hier -filter {REF_NAME =~ URAM288*}] {
    puts $f "URAM $c A=[get_property CASCADE_ORDER_A $c] B=[get_property CASCADE_ORDER_B $c]"
    foreach p [get_pins -of_objects $c -filter {DIRECTION == IN && REF_PIN_NAME =~ CAS_IN_*}] {
        set n [get_nets -quiet -of_objects $p]
        set drivers [get_pins -quiet -of_objects $n -filter {DIRECTION == OUT}]
        puts $f "$p NET=$n DRIVER=$drivers"
    }
}
foreach n [get_nets -hier -filter {ROUTE_STATUS == NOLOADS}] {
    puts $f "NOLOAD $n PINS=[get_pins -of_objects $n] PORTS=[get_ports -quiet -of_objects $n]"
}
close $f
check_timing -verbose -file [file join $out coverage.rpt]
report_clock_networks -file [file join $out clock_networks.rpt]
report_drc -checks RTSTAT-10 -file [file join $out noload_drc.rpt]
set df [open [file join $out noload_objects.txt] w]
foreach v [get_drc_violations] {
    report_property -all $v -file [file join $out violation_properties.txt] -append
    puts $df "$v NETS=[get_nets -quiet -of_objects $v]"
}
close $df
if {$hook ne ""} {
    cd $out
    source $hook
    report_drc -file [file join $out repaired_drc.rpt]
}
exit
