# Read-only inspection of the actual fresh routed checkpoint; no design changes.
if {[llength $argv] != 2} {error "usage: review_cdc.tcl routed.dcp NEW_RESULT"}
lassign $argv dcp out
if {[file exists $out]} {error "refusing existing result"}
file mkdir $out
open_checkpoint $dcp
set f [open [file join $out cdc_physical.txt] w]
set serdes [get_cells -hier -filter {REF_NAME == ISERDESE3}]
if {[llength $serdes] != 16} {error "Expected original 16 ISERDESE3 lanes"}
foreach c $serdes {
    set clk [get_nets -segments -of_objects [get_pins $c/CLK]]
    set clkb [get_nets -segments -of_objects [get_pins $c/CLK_B]]
    puts $f "OBSERVED=$c CLK=$clk CLK_B=$clkb INVERT=[get_property IS_CLK_B_INVERTED $c]"
    if {[lsort $clk] ne [lsort $clkb] || [get_property IS_CLK_B_INVERTED $c] ni {1 1'b1}} {
        error "SERDES must use one clock net with local inversion: $c"
    }
    puts $f "SERDES=$c CLK_NET=$clk CLK_B_NET=$clkb LOCAL_INVERT=[get_property IS_CLK_B_INVERTED $c] LOC=[get_property LOC $c]"
}
foreach pattern {*clkdet/heartbeat_reg *clkdet/missing_ref_reg *gate/write_ready_reg *delay_reference/inst/qualified_ref_reg*} {
    set cells [get_cells -hier -filter "NAME =~ $pattern"]
    puts $f "REGISTER_PATTERN=$pattern COUNT=[llength $cells] CELLS=$cells"
    foreach c $cells {puts $f "FF=$c TYPE=[get_property REF_NAME $c] LOC=[get_property LOC $c]"}
}
foreach c [get_cells -hier -filter {REF_NAME == BUFGCE_DIV}] {
    set pins [get_pins -leaf -of_objects [get_nets -segments -of_objects [get_pins $c/CLR]] -filter {DIRECTION == OUT}]
    puts $f "DIVIDER=$c CLR_DRIVER=$pins"
    if {![string match *reset_divider/arststages_ff_reg* $pins]} {error "Divider CLR lacks actual undivided-clock reset synchronizer"}
}
foreach c [get_cells -hier -filter {NAME =~ *arststages_ff_reg* || NAME =~ *syncstages_ff_reg*}] {
    puts $f "CDC_FF=$c CLOCK=[get_clocks -of_objects [get_pins $c/C]] ASYNC_REG=[get_property ASYNC_REG $c]"
}
close $f
report_timing -delay_type min -from $serdes -max_paths 16 -file [file join $out serdes_hold.rpt]
report_clock_interaction -file [file join $out clock_interaction.rpt]
exit
