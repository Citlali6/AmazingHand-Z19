if {$argc<1 || $argc>2} {puts stderr "Usage: xsct run.tcl BUILD_DIR [INITIALIZATION_DIR]";exit 1}
set build [file normalize [lindex $argv 0]]
if {![file isfile "$build/capture.elf"]} {puts stderr "ELF missing";exit 1}
if {[catch {
 connect -url tcp:127.0.0.1:3121
 if {$argc==2} {
  set hw [file normalize [lindex $argv 1]]
  if {![file isfile "$hw/psu_init.tcl"] || ![file isfile "$hw/design_1_wrapper.bit"]} {error "Matching psu_init.tcl and bitstream required"}
  targets -set -filter {name == "PSU"}
  rst -system
  after 1500
  source "$hw/psu_init.tcl"
  psu_init
  targets -set -filter {name == "PL"}
  fpga -file "$hw/design_1_wrapper.bit"
  targets -set -filter {name == "PSU"}
  psu_ps_pl_isolation_removal
  psu_ps_pl_reset_config
 }
 targets -set -filter {name =~ "Cortex-A53 #0"}
 stop
 rst -processor -clear-registers
 dow "$build/capture.elf"
 con
 puts CAMERA_APP_RUNNING
} err]} {puts stderr $err;exit 1}
exit
