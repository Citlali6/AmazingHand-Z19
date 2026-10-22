# OOC synthesis only. Never loads a device or changes the existing BD/bitstream.
if {$argc != 1} {error "usage: synth_ooc.tcl NEW_OUTPUT_DIRECTORY"}
set out [file normalize [lindex $argv 0]]
if {[file exists $out]} {error "Output directory already exists; preserve prior evidence"}
file mkdir $out
set root [file normalize [file join [file dirname [info script]] ..]]
create_project -in_memory -part xczu19eg-ffvc1760-2-i
read_verilog -sv [file join $root vendor laperex cv_types.sv]
read_verilog -sv [file join $root vendor laperex cv_rgb_to_hsv.sv]
read_verilog -sv [file join $root rtl vg_color_axis.sv]
synth_design -top vg_color_axis -part xczu19eg-ffvc1760-2-i -mode out_of_context
create_clock -name video_clk -period 10.000 [get_ports aclk]
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -file [file join $out timing_synth_only.rpt]
write_checkpoint [file join $out color_axis_synth.dcp]
puts "COLOR_SYNTH_PASS: OOC only; no placement, routing or board validation"
exit
