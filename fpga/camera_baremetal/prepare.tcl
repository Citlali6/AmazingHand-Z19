if {$argc != 2} {puts stderr "Usage: xsct prepare.tcl XSA NEW_OUTPUT_DIR";exit 1}
set xsa [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file isfile $xsa] || [file exists $out]} {puts stderr "XSA missing or output already exists";exit 1}
if {[catch {
 file mkdir $out
 file copy $xsa "$out/camera.xsa"
 setws "$out/ws"
 platform create -name camera_hw -hw "$out/camera.xsa" -proc psu_cortexa53_0 -os standalone -out "$out/platform"
 platform generate
 puts "BSP: $out/platform/camera_hw/psu_cortexa53_0/standalone_domain/bsp/psu_cortexa53_0"
} err]} {puts stderr $err;exit 1}
exit
