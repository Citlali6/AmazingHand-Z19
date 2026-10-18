# Experimental post-opt and post-route hook. No DRC rule or severity is changed.
# The original routed DCP proves four standalone VDMA URAM288, NONE/NONE,
# with disconnected cascade inputs. Actual 2020.1 REQP-1869 requires these low.
set log [open [file join [pwd] netlist_repair.txt] a]
set urams [get_cells -hier -filter {REF_NAME =~ URAM288*}]
if {[llength $urams] != 4} {error "Expected exactly four archived VDMA URAMs"}
set gnd [get_nets -quiet ah_unused_cascade_gnd]
if {![llength $gnd]} {
    create_cell -reference GND ah_unused_cascade_gnd_driver
    create_net ah_unused_cascade_gnd
    set gnd [get_nets ah_unused_cascade_gnd]
    connect_net -net $gnd -objects [get_pins ah_unused_cascade_gnd_driver/G]
}
set tied 0
foreach c $urams {
    if {![regexp {^design_1_i/axi_vdma_[0-3]/U0/.*mem_reg_uram_0$} $c] ||
        [get_property CASCADE_ORDER_A $c] ne "NONE" ||
        [get_property CASCADE_ORDER_B $c] ne "NONE"} {error "Unexpected URAM mode/path: $c"}
    foreach p [get_pins -of_objects $c -filter {DIRECTION == IN && REF_PIN_NAME =~ CAS_IN_*}] {
        set old [get_nets -quiet -of_objects $p]
        if {![llength $old]} {
            connect_net -hier -net $gnd -objects $p
            if {![llength [get_nets -quiet -of_objects $p]]} {error "Cascade tie failed: $p"}
            incr tied
        } elseif {$old ne $gnd} {
            set drivers [get_pins -quiet -leaf -of_objects [get_nets -segments $old] -filter {DIRECTION == OUT}]
            set cells [get_cells -quiet -of_objects $drivers]
            if {[llength $cells] != 1 || [get_property REF_NAME $cells] ne "GND"} {
                error "Refusing driven non-GND cascade input $p: $old ($drivers)"
            }
        }
    }
}
puts $log "URAM_NONE_UNDRIVEN_CASCADE_INPUTS_TIED_LOW=$tied"
# Remove only nets with a proved primitive output and zero primitive inputs or
# external ports. Hierarchical aliases are resolved with -segments and -leaf.
# This disconnects unused outputs; it removes no functional load or cell.
set removed 0
foreach n [get_nets -hier -filter {ROUTE_STATUS == NOLOADS}] {
    # Limit to the proved unused FIFO status outputs named in actual RTSTAT-10.
    # Do not edit encrypted debug internals, macro sub-pins, buses, or resets.
    if {![regexp {/(overflow|underflow|aempty_fwft_i|ram_empty_i)$} $n]} {continue}
    if {![llength [get_nets -quiet $n]]} {continue}
    set segments [get_nets -quiet -segments $n]
    set protected 0
    foreach flag [get_property DONT_TOUCH $segments] {
        if {$flag eq "1" || [string equal -nocase $flag true]} {set protected 1}
    }
    if {$protected} {puts $log "RETAINED_PROTECTED_NOLOAD_NET=$n"; continue}
    set leaf [get_pins -quiet -leaf -of_objects $segments]
    set inputs [filter $leaf {DIRECTION == IN}]
    set outputs [filter $leaf {DIRECTION == OUT}]
    set ports [get_ports -quiet -of_objects $segments]
    if {[llength $inputs] == 0 && [llength $outputs] == 1 && [llength $ports] == 0} {
        remove_net $segments
        if {[llength [get_nets -quiet $n]]} {
            puts $log "RETAINED_NOLOAD_NET_AFTER_NATIVE_REMOVE=$n DRIVER=$outputs"
        } else {
            puts $log "REMOVED_UNUSED_NET=$n DRIVER=$outputs INPUTS=0 PORTS=0"
            incr removed
        }
    } else {puts $log "RETAINED_NOLOAD_NET=$n OUTPUTS=$outputs INPUTS=$inputs PORTS=$ports"}
}
puts $log "UNUSED_OUTPUT_NETS_REMOVED=$removed"
close $log
