if {$argc!=2} {puts stderr "Usage: xsct stream.tcl BUILD_DIR RUNTIME_DIR";exit 1}
set build [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
source "$build/symbols.tcl"
connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "Cortex-A53 #0"}
set sequence 0
set start [clock milliseconds]
if {[catch {
while {![file exists "$out/stop.request"]} {
 if {[file exists "$out/focus.request"]} {
  set f [open "$out/focus.request" r];set pos [string trim [read $f]];close $f
  if {[string is integer -strict $pos] && $pos>=0 && $pos<=1023} {mwr $addr(focus_request) $pos}
 }
 incr sequence
 mwr $addr(preview_request) $sequence
 set ready 0
 for {set n 0} {$n<100} {incr n} {
  set ack [lindex [mrd -value $addr(preview_sequence) 1] 0]
  if {$ack==$sequence} {set ready 1;break}
  after 10
 }
 if {!$ready} {error "Preview timeout: [mrd -value $addr(preview_status) 1]"}
 set count [lindex [mrd -value $addr(board_frames) 1] 0]
 set status [lindex [mrd -value $addr(preview_status) 1] 0]
 if {$status!=0} {error "Camera status $status"}
 set focus [lindex [mrd -value $addr(focus_applied) 1] 0]
 set focusrc [lindex [mrd -value $addr(focus_result) 1] 0]
 set debug [mrd -value $addr(debug_info) 8]
 set stem [format "$out/frame_%08d" $sequence]
 mrd -bin -file "$stem.raw" $addr(preview_rgb) 43200
 set f [open "$stem.json" w]
 puts $f "{\"sequence\":$sequence,\"board_frames\":$count,\"status\":$status,\"focus\":$focus,\"focus_result\":$focusrc,\"debug\":\[[join $debug ,]\],\"elapsed_ms\":[expr {[clock milliseconds]-$start}]}"
 close $f
 puts "PREVIEW $sequence board_frames=$count focus=$focus focus_rc=$focusrc";flush stdout
 after 100
}
mwr $addr(preview_request) 0xffffffff
} err]} {
 puts stderr "LIVE_STREAM_ERROR: $err"
 set f [open "$out/stream_error.txt" w];puts $f $err;close $f
 exit 1
}
puts LIVE_STREAM_STOPPED
exit
