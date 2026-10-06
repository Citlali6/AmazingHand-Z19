# ============================================================================
# build_system.tcl - AmazingHand one-shot build (competition reproducibility)
#
# Usage (Windows PowerShell / Linux):
#   vivado -mode batch -source fpga/scripts/build_system.tcl
# Outputs:
#   fpga/vivado/ah_hand/ah_hand.runs/impl_1/ah_bd_wrapper.bit
#   fpga/vivado/ah_hand.xsa
#
# Architecture: Zynq PS (ALINX official preset) -> M_AXI_HPM0 (GP0, 0x8000_0000)
#   -> top.sv (module ref: MMCM + axi_lite_regs + grasp_fsm + SCS bus)
# PS preset source: alinx/ps_config.tcl (github.com/alinxalinx/Z19, unmodified)
# ============================================================================
set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ../..]]
set alinx_dir  [file join $script_dir alinx]
set rtl_dir    [file join $repo_root fpga/rtl]
set xdc_file   [file join $repo_root fpga/constr z19.xdc]
set proj_dir   [file join $repo_root fpga/vivado]
set proj_name  ah_hand
set bd_name    ah_bd

source [file join $alinx_dir project_info.tcl]

# ---- 1. project ----
create_project -force $proj_name $proj_dir -part $devicePart
add_files -norecurse [glob [file join $rtl_dir *.sv]]
set_property top top [current_fileset]
update_compile_order -fileset sources_1

# ---- 2. BD + Zynq PS (official preset) ----
create_bd_design $bd_name
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 ps0
source [file join $alinx_dir ps_config.tcl]
set_ps_config ps0

# Project additions: GP master (0x8000_0000 window) + IRQ0 (level high)
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__IRQ0      {1} \
    CONFIG.PSU__IRQ_P2F__IRQ0__TYPE {LEVEL_HIGH} \
] [get_bd_cells ps0]

# ---- 3. our top.sv as module-ref cell ----
create_bd_cell -type module -reference top ah_top

# ---- 4. external ports (names MUST match fpga/constr/z19.xdc) ----
create_bd_port -dir I  pl_clk0_p
create_bd_port -dir I  pl_clk0_n
create_bd_port -dir I  -from 0 -to 0 rst_n_btn
create_bd_port -dir IO -from 0 -to 0 servo_data
create_bd_port -dir O  -from 0 -to 0 heartbeat
connect_bd_net [get_bd_ports pl_clk0_p]  [get_bd_pins ah_top/pl_clk0_p]
connect_bd_net [get_bd_ports pl_clk0_n]  [get_bd_pins ah_top/pl_clk0_n]
connect_bd_net [get_bd_ports rst_n_btn]  [get_bd_pins ah_top/rst_n_btn]
connect_bd_net [get_bd_ports servo_data] [get_bd_pins ah_top/servo_data]
connect_bd_net [get_bd_ports heartbeat]  [get_bd_pins ah_top/heartbeat]

# ---- 5. AXI direct: PS GP0 -> top, same clock domain (clk_axi) ----
# module-ref AXI inference check: if Vivado did not bundle the s_axi_* ports
# into an interface pin, tell the user the one-click GUI fallback instead of
# dying with an obscure tcl error.
if {[llength [get_bd_intf_pins -quiet ah_top/s_axi]] == 0} {
    error "AXI interface NOT inferred on ah_top.\
 Open the BD in GUI: right-click ah_top -> 'Infer Interfaces',\
 save, then re-run this script (or wire ps0/M_AXI_HPM0 manually)."
}
connect_bd_intf_net [get_bd_intf_pins ps0/M_AXI_HPM0] [get_bd_intf_pins ah_top/s_axi]
connect_bd_net [get_bd_pins ah_top/clk_axi] [get_bd_pins ps0/maxihpm0_lpd_aclk]

# ---- 6. IRQ chain: ah_top/irq -> concat -> pl_ps_irq0[0] ----
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_cat
set_property -dict [list CONFIG.NUM_PORTS {8}] [get_bd_cells irq_cat]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 irq_low
set_property -dict [list CONFIG.CONST_WIDTH {7} CONFIG.CONST_VAL {0}] [get_bd_cells irq_low]
connect_bd_net [get_bd_pins ah_top/irq]   [get_bd_pins irq_cat/In0]
connect_bd_net [get_bd_pins irq_low/dout] [get_bd_pins irq_cat/In1]
connect_bd_net [get_bd_pins irq_cat/dout] [get_bd_pins ps0/pl_ps_irq0]

# ---- 7. address: GP0 window 0x8000_0000 (matches backend_fpga.py) ----
set seg [lindex [get_bd_addr_segs -quiet ah_top/s_axi/*] 0]
if {$seg eq ""} { error "No address segment on ah_top/s_axi - check AXI inference" }
assign_bd_address -target_address_space /ps0/M_AXI_HPM0 $seg -offset 0x80000000 -range 64K

regenerate_bd_layout
validate_bd_design
save_bd_design
make_wrapper -files [get_files [file join $proj_dir $proj_name.srcs sources_1 bd $bd_name $bd_name.bd]] -top
add_files -norecurse [glob [file join $proj_dir $proj_name.srcs sources_1 bd $bd_name hdl *.v]]
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

# ---- 8. constraints ----
add_files -fileset constrs_1 -norecurse $xdc_file

# ---- 9. build: synth -> impl -> bitstream -> xsa ----
launch_runs impl_1 -to_step write_bitstream -jobs $runs_jobs
wait_on_run impl_1
if {[string equal [get_property PROGRESS [get_runs impl_1]] "100%"] ne 1} {
    error "Implementation failed - check fpga/vivado/ah_hand/ah_hand.runs/impl_1/runme.log"
}
write_hw_platform -fixed -include_bit -force [file join $proj_dir $proj_name.xsa]
puts "BUILD OK:"
puts "  bit: [file join $proj_dir $proj_name.runs impl_1 ${bd_name}_wrapper.bit]"
puts "  xsa: [file join $proj_dir $proj_name.xsa]"
