open_checkpoint F:/ah-camera-hil-cdc-run01/vivado/mipi_dp.runs/impl_1/design_1_wrapper_routed.dcp
set f [open F:/ah-camera-hil-cdc-inspect01.txt w]
foreach c [get_cells -hier -filter {REF_NAME == ISERDESE3}] {
 puts $f "CELL=$c INVERT=[get_property IS_CLK_B_INVERTED $c] CLKI=[get_property IS_CLK_INVERTED $c]"
 foreach port {CLK CLK_B} {
  set p [get_pins $c/$port]
  set n [get_nets -of_objects $p]
  puts $f "$port PIN=$p LOCALNET=$n SEGMENTS=[get_nets -segments -of_objects $p] DRIVER=[get_pins -leaf -of_objects [get_nets -segments -of_objects $p] -filter {DIRECTION == OUT}]"
 }
}
close $f
exit
