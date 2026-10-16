# Recreate an editable project from the archived source inputs, not a new design.
# Vivado 2020.2: -mode batch -source create_project.tcl -tclargs NEW_OUTPUT_DIR
# No synthesis, bitstream generation, IP upgrade or hardware download is run.
if {[version -short] ne "2020.2"} {
    error "This source project requires Vivado 2020.2 (original: 2020.2_AR75986). Do not downgrade IP."
}
if {$argc != 1} { error "usage: create_project.tcl NEW_OUTPUT_DIR" }
set output_dir [file normalize [lindex $argv 0]]
if {[file exists $output_dir]} { error "Output exists; refusing overwrite: $output_dir" }
set archive_dir [file normalize [file join [file dirname [info script]] .. project]]
if {![file isdirectory $archive_dir]} { error "Archived source inputs are missing" }
# All generated files remain in a new work directory, away from Git sources.
file mkdir $output_dir
file copy $archive_dir [file join $output_dir source]
set source_dir [file join $output_dir source]
create_project mipi_dp [file join $output_dir vivado] -part xczu19eg-ffvc1760-2-i
set_property ip_repo_paths [list [file join $source_dir repo]] [current_project]
update_ip_catalog
foreach relative {
    mipi_dp.srcs/sources_1/new/axis_pixel_counter.v
    mipi_dp.srcs/sources_1/bd/design_1/design_1.bd
    mipi_dp.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v
    import/pipeline_latency_timer.v
    mipi_dp.srcs/sources_1/new/frame_ptr_trigger.v
    import/frame_event_counter.v
    mipi_dp.srcs/sources_1/new/bus_sync.v
} {
    add_files -norecurse [file join $source_dir $relative]
}
foreach relative {system.xdc mipi.xdc QSFP.xdc ddr4_set.xdc mipi2.xdc} {
    add_files -fileset constrs_1 -norecurse [file join $source_dir mipi_dp.srcs constrs_1 new $relative]
}
set_property top design_1_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "CAMERA_SOURCE_PROJECT_CREATED: [file join $output_dir vivado mipi_dp.xpr]"
puts "Source archive only; validate BD/IP, implementation and timing with the matching toolchain before replacing the reviewed bit."
