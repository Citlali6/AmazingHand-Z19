# Physical inspection of the NEW completed implementation; no implementation edit.
if {[llength $argv] != 2} {error "usage: review_impl.tcl routed.dcp NEW_RESULT"}
lassign $argv dcp out
if {[file exists $out]} {error "result already exists"}
file mkdir $out
open_checkpoint $dcp
set f [open [file join $out physical_reference.txt] w]
set m [get_cells -hier -filter {REF_NAME =~ MMCME4*}]
if {[llength $m] != 1 || ![string match *delay_reference* $m]} {error "Expected one shared MMCM"}
puts $f "MMCM=$m M=[get_property CLKFBOUT_MULT_F $m] D=[get_property DIVCLK_DIVIDE $m] O=[get_property CLKOUT0_DIVIDE_F $m] LOC=[get_property LOC $m]"
set controls [get_cells -hier -filter {REF_NAME == IDELAYCTRL}]
set clocks {}
foreach c $controls {
    set clk [get_clocks -of_objects [get_pins $c/REFCLK]]
    if {[llength $clk] != 1} {error "Controller has ambiguous/no reference clock: $c"}
    lappend clocks $clk
    set reset [get_nets -segments -of_objects [get_pins $c/RST]]
    set driver [get_pins -leaf -of_objects $reset -filter {DIRECTION == OUT}]
    puts $f "CTRL=$c LOC=[get_property LOC $c] CLOCK=$clk PERIOD=[get_property PERIOD $clk] RST_DRIVER=$driver"
}
if {[llength [lsort -unique $clocks]] != 1} {error "Controllers do not share one actual reference clock"}
foreach c [get_cells -hier -filter {REF_NAME == IDELAYE3}] {
    set reset [get_nets -segments -of_objects [get_pins $c/RST]]
    set driver [get_pins -leaf -of_objects $reset -filter {DIRECTION == OUT}]
    puts $f "DELAY=$c LOC=[get_property LOC $c] FORMAT=[get_property DELAY_FORMAT $c] REFCLK_MHZ=[get_property REFCLK_FREQUENCY $c] VALUE=[get_property DELAY_VALUE $c] RST_DRIVER=$driver"
}
puts $f "CONTROLLER_COUNT=[llength $controls]"
foreach i {0 1 2 3} {
    set pin [get_pins design_1_i/delay_reference/inst/ready$i]
    set drivers [get_pins -leaf -of_objects [get_nets -segments -of_objects $pin] -filter {DIRECTION == OUT}]
    puts $f "CSI_RDY_RETURN_$i=$drivers"
    puts $f "CSI_RDY_STARTPOINTS_$i=[all_fanin -flat -startpoints_only -to $pin]"
}
close $f
report_clock_interaction -file [file join $out clock_interaction.rpt]
exit
