if {[version -short] ne "2020.1"} {error "Experimental reconstruction requires installed Vivado 2020.1"}
set out {F:/ah-camera-hil-2020.1-p0-run04}
create_project mipi_dp [file join $out vivado] -part xczu19eg-ffvc1760-2-i
set_property ip_repo_paths [list [file join $out source repo]] [current_project]
update_ip_catalog
add_files -norecurse [file join $out source {mipi_dp.srcs/sources_1/new/axis_pixel_counter.v}]
add_files -norecurse [file join $out source {import/pipeline_latency_timer.v}]
add_files -norecurse [file join $out source {mipi_dp.srcs/sources_1/new/frame_ptr_trigger.v}]
add_files -norecurse [file join $out source {import/frame_event_counter.v}]
add_files -norecurse [file join $out source {mipi_dp.srcs/sources_1/new/bus_sync.v}]
add_files -norecurse [glob [file join $out hil_rtl *]]
add_files -norecurse [file join $out csi_delay_reference.v]
update_compile_order -fileset sources_1
create_bd_design design_1
set catalog [open [file join $out catalog.txt] w]
set defs [get_ipdefs -all {alinx.com.cn:user:csi_4lane_raw10:2.0}]
puts $catalog "alinx.com.cn:user:csi_4lane_raw10:2.0	$defs"
if {![llength $defs]} {error "2020.1 catalog missing alinx.com.cn:user:csi_4lane_raw10:2.0"}
set defs [get_ipdefs -all {digilentinc.com:user:AXI_BayerToRGB:1.3}]
puts $catalog "digilentinc.com:user:AXI_BayerToRGB:1.3	$defs"
if {![llength $defs]} {error "2020.1 catalog missing digilentinc.com:user:AXI_BayerToRGB:1.3"}
set defs [get_ipdefs -all {digilentinc.com:user:AXI_GammaCorrection:1.0}]
puts $catalog "digilentinc.com:user:AXI_GammaCorrection:1.0	$defs"
if {![llength $defs]} {error "2020.1 catalog missing digilentinc.com:user:AXI_GammaCorrection:1.0"}
set defs [get_ipdefs -all {xilinx.com:ip:axi_gpio:2.0}]
puts $catalog "xilinx.com:ip:axi_gpio:2.0	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:axi_gpio:2.0"}
set defs [get_ipdefs -all {xilinx.com:ip:axi_iic:2.0}]
puts $catalog "xilinx.com:ip:axi_iic:2.0	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:axi_iic:2.0"}
set defs [get_ipdefs -all {xilinx.com:ip:axi_interconnect:2.1}]
puts $catalog "xilinx.com:ip:axi_interconnect:2.1	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:axi_interconnect:2.1"}
set defs [get_ipdefs -all {xilinx.com:ip:axi_vdma:6.3}]
puts $catalog "xilinx.com:ip:axi_vdma:6.3	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:axi_vdma:6.3"}
set defs [get_ipdefs -all {xilinx.com:ip:axis_subset_converter:1.1}]
puts $catalog "xilinx.com:ip:axis_subset_converter:1.1	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:axis_subset_converter:1.1"}
set defs [get_ipdefs -all {xilinx.com:ip:proc_sys_reset:5.0}]
puts $catalog "xilinx.com:ip:proc_sys_reset:5.0	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:proc_sys_reset:5.0"}
set defs [get_ipdefs -all {xilinx.com:ip:smartconnect:1.0}]
puts $catalog "xilinx.com:ip:smartconnect:1.0	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:smartconnect:1.0"}
set defs [get_ipdefs -all {xilinx.com:ip:system_ila:1.1}]
puts $catalog "xilinx.com:ip:system_ila:1.1	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:system_ila:1.1"}
set defs [get_ipdefs -all {xilinx.com:ip:xlconcat:2.1}]
puts $catalog "xilinx.com:ip:xlconcat:2.1	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:xlconcat:2.1"}
set defs [get_ipdefs -all {xilinx.com:ip:xlconstant:1.1}]
puts $catalog "xilinx.com:ip:xlconstant:1.1	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:xlconstant:1.1"}
set defs [get_ipdefs -all {xilinx.com:ip:zynq_ultra_ps_e:3.3}]
puts $catalog "xilinx.com:ip:zynq_ultra_ps_e:3.3	$defs"
if {![llength $defs]} {error "2020.1 catalog missing xilinx.com:ip:zynq_ultra_ps_e:3.3"}
close $catalog
set audit [open [file join $out property-audit.txt] w]
set unsupported 0
create_bd_cell -type ip -vlnv {digilentinc.com:user:AXI_GammaCorrection:1.0} AXI_GammaCorrection_0
set cell [get_bd_cells AXI_GammaCorrection_0]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {digilentinc.com:user:AXI_GammaCorrection:1.0} AXI_GammaCorrection_1
set cell [get_bd_cells AXI_GammaCorrection_1]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {xilinx.com:ip:axi_gpio:2.0} csi_rst
set cell [get_bd_cells csi_rst]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.C_ALL_OUTPUTS] < 0} {incr unsupported; puts $audit "MISSING	csi_rst	C_ALL_OUTPUTS	1"}
if {[lsearch -exact $props CONFIG.C_GPIO_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	csi_rst	C_GPIO_WIDTH	4"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_GPIO_WIDTH {4}] $cell} reason]} {
puts $audit "SET_FAILED	csi_rst	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	csi_rst	2 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axi_vdma:6.3} axi_vdma_0
set cell [get_bd_cells axi_vdma_0]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.c_addr_width] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_0	c_addr_width	64"}
if {[lsearch -exact $props CONFIG.c_include_mm2s] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_0	c_include_mm2s	0"}
if {[lsearch -exact $props CONFIG.c_include_s2mm_dre] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_0	c_include_s2mm_dre	1"}
if {[lsearch -exact $props CONFIG.c_num_fstores] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_0	c_num_fstores	3"}
if {[lsearch -exact $props CONFIG.c_s2mm_genlock_mode] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_0	c_s2mm_genlock_mode	0"}
if {[lsearch -exact $props CONFIG.c_s2mm_linebuffer_depth] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_0	c_s2mm_linebuffer_depth	4096"}
if {[lsearch -exact $props CONFIG.c_s2mm_max_burst_length] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_0	c_s2mm_max_burst_length	128"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.c_addr_width {64} CONFIG.c_include_mm2s {0} CONFIG.c_include_s2mm_dre {1} CONFIG.c_num_fstores {3} CONFIG.c_s2mm_genlock_mode {0} CONFIG.c_s2mm_linebuffer_depth {4096} CONFIG.c_s2mm_max_burst_length {128}] $cell} reason]} {
puts $audit "SET_FAILED	axi_vdma_0	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axi_vdma_0	7 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axi_vdma:6.3} axi_vdma_1
set cell [get_bd_cells axi_vdma_1]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.c_addr_width] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_1	c_addr_width	64"}
if {[lsearch -exact $props CONFIG.c_include_mm2s] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_1	c_include_mm2s	0"}
if {[lsearch -exact $props CONFIG.c_include_s2mm_dre] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_1	c_include_s2mm_dre	1"}
if {[lsearch -exact $props CONFIG.c_num_fstores] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_1	c_num_fstores	3"}
if {[lsearch -exact $props CONFIG.c_s2mm_genlock_mode] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_1	c_s2mm_genlock_mode	0"}
if {[lsearch -exact $props CONFIG.c_s2mm_linebuffer_depth] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_1	c_s2mm_linebuffer_depth	4096"}
if {[lsearch -exact $props CONFIG.c_s2mm_max_burst_length] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_1	c_s2mm_max_burst_length	128"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.c_addr_width {64} CONFIG.c_include_mm2s {0} CONFIG.c_include_s2mm_dre {1} CONFIG.c_num_fstores {3} CONFIG.c_s2mm_genlock_mode {0} CONFIG.c_s2mm_linebuffer_depth {4096} CONFIG.c_s2mm_max_burst_length {128}] $cell} reason]} {
puts $audit "SET_FAILED	axi_vdma_1	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axi_vdma_1	7 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axis_subset_converter:1.1} axis_subset_converter_0
set cell [get_bd_cells axis_subset_converter_0]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.M_HAS_TKEEP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	M_HAS_TKEEP	1"}
if {[lsearch -exact $props CONFIG.M_HAS_TLAST] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	M_HAS_TLAST	1"}
if {[lsearch -exact $props CONFIG.M_HAS_TSTRB] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	M_HAS_TSTRB	0"}
if {[lsearch -exact $props CONFIG.M_TDATA_NUM_BYTES] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	M_TDATA_NUM_BYTES	3"}
if {[lsearch -exact $props CONFIG.M_TDEST_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	M_TDEST_WIDTH	0"}
if {[lsearch -exact $props CONFIG.M_TID_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	M_TID_WIDTH	0"}
if {[lsearch -exact $props CONFIG.M_TUSER_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	M_TUSER_WIDTH	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TKEEP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	S_HAS_TKEEP	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TLAST] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	S_HAS_TLAST	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TSTRB] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	S_HAS_TSTRB	0"}
if {[lsearch -exact $props CONFIG.S_TDATA_NUM_BYTES] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	S_TDATA_NUM_BYTES	3"}
if {[lsearch -exact $props CONFIG.S_TDEST_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	S_TDEST_WIDTH	0"}
if {[lsearch -exact $props CONFIG.S_TID_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	S_TID_WIDTH	0"}
if {[lsearch -exact $props CONFIG.S_TUSER_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	S_TUSER_WIDTH	1"}
if {[lsearch -exact $props CONFIG.TDATA_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	TDATA_REMAP	tdata[23:16],tdata[7:0],tdata[15:8]"}
if {[lsearch -exact $props CONFIG.TDEST_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	TDEST_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TID_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	TID_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TKEEP_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	TKEEP_REMAP	tkeep[2:0]"}
if {[lsearch -exact $props CONFIG.TLAST_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	TLAST_REMAP	tlast[0]"}
if {[lsearch -exact $props CONFIG.TSTRB_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	TSTRB_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TUSER_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_0	TUSER_REMAP	tuser[0:0]"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.M_HAS_TKEEP {1} CONFIG.M_HAS_TLAST {1} CONFIG.M_HAS_TSTRB {0} CONFIG.M_TDATA_NUM_BYTES {3} CONFIG.M_TDEST_WIDTH {0} CONFIG.M_TID_WIDTH {0} CONFIG.M_TUSER_WIDTH {1} CONFIG.S_HAS_TKEEP {1} CONFIG.S_HAS_TLAST {1} CONFIG.S_HAS_TSTRB {0} CONFIG.S_TDATA_NUM_BYTES {3} CONFIG.S_TDEST_WIDTH {0} CONFIG.S_TID_WIDTH {0} CONFIG.S_TUSER_WIDTH {1} CONFIG.TDATA_REMAP {tdata[23:16],tdata[7:0],tdata[15:8]} CONFIG.TDEST_REMAP {1'b0} CONFIG.TID_REMAP {1'b0} CONFIG.TKEEP_REMAP {tkeep[2:0]} CONFIG.TLAST_REMAP {tlast[0]} CONFIG.TSTRB_REMAP {1'b0} CONFIG.TUSER_REMAP {tuser[0:0]}] $cell} reason]} {
puts $audit "SET_FAILED	axis_subset_converter_0	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axis_subset_converter_0	21 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axis_subset_converter:1.1} axis_subset_converter_1
set cell [get_bd_cells axis_subset_converter_1]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.M_HAS_TKEEP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	M_HAS_TKEEP	1"}
if {[lsearch -exact $props CONFIG.M_HAS_TLAST] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	M_HAS_TLAST	1"}
if {[lsearch -exact $props CONFIG.M_TDATA_NUM_BYTES] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	M_TDATA_NUM_BYTES	3"}
if {[lsearch -exact $props CONFIG.M_TUSER_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	M_TUSER_WIDTH	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TKEEP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	S_HAS_TKEEP	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TLAST] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	S_HAS_TLAST	1"}
if {[lsearch -exact $props CONFIG.S_TDATA_NUM_BYTES] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	S_TDATA_NUM_BYTES	3"}
if {[lsearch -exact $props CONFIG.S_TUSER_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	S_TUSER_WIDTH	1"}
if {[lsearch -exact $props CONFIG.TDATA_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	TDATA_REMAP	tdata[23:16],tdata[7:0],tdata[15:8]"}
if {[lsearch -exact $props CONFIG.TDEST_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	TDEST_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TID_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	TID_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TKEEP_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	TKEEP_REMAP	tkeep[2:0]"}
if {[lsearch -exact $props CONFIG.TLAST_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	TLAST_REMAP	tlast[0]"}
if {[lsearch -exact $props CONFIG.TSTRB_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	TSTRB_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TUSER_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_1	TUSER_REMAP	tuser[0:0]"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.M_HAS_TKEEP {1} CONFIG.M_HAS_TLAST {1} CONFIG.M_TDATA_NUM_BYTES {3} CONFIG.M_TUSER_WIDTH {1} CONFIG.S_HAS_TKEEP {1} CONFIG.S_HAS_TLAST {1} CONFIG.S_TDATA_NUM_BYTES {3} CONFIG.S_TUSER_WIDTH {1} CONFIG.TDATA_REMAP {tdata[23:16],tdata[7:0],tdata[15:8]} CONFIG.TDEST_REMAP {1'b0} CONFIG.TID_REMAP {1'b0} CONFIG.TKEEP_REMAP {tkeep[2:0]} CONFIG.TLAST_REMAP {tlast[0]} CONFIG.TSTRB_REMAP {1'b0} CONFIG.TUSER_REMAP {tuser[0:0]}] $cell} reason]} {
puts $audit "SET_FAILED	axis_subset_converter_1	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axis_subset_converter_1	15 original parameters"}}
create_bd_cell -type ip -vlnv {alinx.com.cn:user:csi_4lane_raw10:2.0} csi_4lane_raw10_0
set cell [get_bd_cells csi_4lane_raw10_0]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.series] < 0} {incr unsupported; puts $audit "MISSING	csi_4lane_raw10_0	series	ULTRASCALE_PLUS"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.series {ULTRASCALE_PLUS}] $cell} reason]} {
puts $audit "SET_FAILED	csi_4lane_raw10_0	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	csi_4lane_raw10_0	1 original parameters"}}
create_bd_cell -type ip -vlnv {alinx.com.cn:user:csi_4lane_raw10:2.0} csi_4lane_raw10_1
set cell [get_bd_cells csi_4lane_raw10_1]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.series] < 0} {incr unsupported; puts $audit "MISSING	csi_4lane_raw10_1	series	ULTRASCALE_PLUS"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.series {ULTRASCALE_PLUS}] $cell} reason]} {
puts $audit "SET_FAILED	csi_4lane_raw10_1	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	csi_4lane_raw10_1	1 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:proc_sys_reset:5.0} proc_sys_reset_100M
set cell [get_bd_cells proc_sys_reset_100M]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {xilinx.com:ip:axi_interconnect:2.1} ps8_0_axi_periph
set cell [get_bd_cells ps8_0_axi_periph]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.NUM_MI] < 0} {incr unsupported; puts $audit "MISSING	ps8_0_axi_periph	NUM_MI	11"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.NUM_MI {11}] $cell} reason]} {
puts $audit "SET_FAILED	ps8_0_axi_periph	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	ps8_0_axi_periph	1 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:xlconstant:1.1} xlconstant_0
set cell [get_bd_cells xlconstant_0]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {xilinx.com:ip:zynq_ultra_ps_e:3.3} zynq_ultra_ps_e_0
set cell [get_bd_cells zynq_ultra_ps_e_0]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.CAN0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	CAN0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.CAN1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	CAN1_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.CSU_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	CSU_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.DP_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	DP_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.GEM0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	GEM0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.GEM1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	GEM1_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.GEM2_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	GEM2_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.GEM3_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	GEM3_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.GPIO_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	GPIO_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.IIC0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	IIC0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.IIC1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	IIC1_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.NAND_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	NAND_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.PCIE_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PCIE_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.PJTAG_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PJTAG_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.PMU_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PMU_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.PSU_BANK_0_IO_STANDARD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_BANK_0_IO_STANDARD	LVCMOS18"}
if {[lsearch -exact $props CONFIG.PSU_BANK_1_IO_STANDARD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_BANK_1_IO_STANDARD	LVCMOS18"}
if {[lsearch -exact $props CONFIG.PSU_BANK_2_IO_STANDARD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_BANK_2_IO_STANDARD	LVCMOS18"}
if {[lsearch -exact $props CONFIG.PSU_BANK_3_IO_STANDARD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_BANK_3_IO_STANDARD	LVCMOS33"}
if {[lsearch -exact $props CONFIG.PSU_DDR_RAM_HIGHADDR] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_DDR_RAM_HIGHADDR	0x1FFFFFFFF"}
if {[lsearch -exact $props CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_DDR_RAM_HIGHADDR_OFFSET	0x800000000"}
if {[lsearch -exact $props CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_DDR_RAM_LOWADDR_OFFSET	0x80000000"}
if {[lsearch -exact $props CONFIG.PSU_MIO_0_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_0_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_0_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_0_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_0_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_0_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_10_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_10_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_10_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_10_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_10_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_10_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_10_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_10_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_11_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_11_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_11_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_11_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_11_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_11_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_11_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_11_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_12_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_12_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_12_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_12_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_12_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_12_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_13_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_13_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_13_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_13_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_13_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_13_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_13_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_13_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_14_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_14_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_14_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_14_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_14_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_14_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_14_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_14_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_15_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_15_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_15_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_15_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_15_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_15_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_15_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_15_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_16_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_16_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_16_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_16_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_16_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_16_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_16_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_16_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_17_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_17_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_17_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_17_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_17_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_17_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_17_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_17_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_18_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_18_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_18_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_18_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_18_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_18_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_18_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_18_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_19_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_19_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_19_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_19_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_19_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_19_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_19_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_19_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_1_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_1_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_1_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_1_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_1_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_1_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_1_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_1_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_20_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_20_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_20_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_20_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_20_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_20_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_20_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_20_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_21_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_21_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_21_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_21_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_21_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_21_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_21_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_21_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_22_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_22_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_22_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_22_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_22_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_22_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_23_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_23_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_23_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_23_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_23_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_23_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_24_DIRECTION] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_24_DIRECTION	inout"}
if {[lsearch -exact $props CONFIG.PSU_MIO_24_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_24_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_24_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_24_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_24_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_24_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_24_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_24_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_25_DIRECTION] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_25_DIRECTION	inout"}
if {[lsearch -exact $props CONFIG.PSU_MIO_25_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_25_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_25_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_25_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_25_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_25_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_25_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_25_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_26_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_26_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_26_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_26_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_26_POLARITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_26_POLARITY	Default"}
if {[lsearch -exact $props CONFIG.PSU_MIO_26_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_26_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_26_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_26_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_27_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_27_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_27_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_27_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_27_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_27_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_28_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_28_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_28_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_28_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_29_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_29_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_29_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_29_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_29_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_29_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_2_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_2_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_2_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_2_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_2_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_2_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_2_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_2_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_30_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_30_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_30_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_30_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_31_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_31_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_31_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_31_INPUT_TYPE	cmos"}
if {[lsearch -exact $props CONFIG.PSU_MIO_31_POLARITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_31_POLARITY	Default"}
if {[lsearch -exact $props CONFIG.PSU_MIO_31_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_31_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_31_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_31_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_32_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_32_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_32_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_32_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_32_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_32_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_33_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_33_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_33_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_33_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_34_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_34_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_34_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_34_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_35_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_35_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_35_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_35_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_35_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_35_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_36_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_36_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_36_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_36_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_36_POLARITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_36_POLARITY	Default"}
if {[lsearch -exact $props CONFIG.PSU_MIO_36_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_36_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_36_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_36_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_37_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_37_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_37_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_37_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_37_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_37_SLEW	fast"}
if {[lsearch -exact $props CONFIG.PSU_MIO_38_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_38_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_38_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_38_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_39_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_39_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_39_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_39_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_39_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_39_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_3_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_3_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_3_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_3_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_3_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_3_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_3_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_3_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_40_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_40_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_40_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_40_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_40_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_40_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_41_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_41_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_41_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_41_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_42_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_42_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_42_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_42_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_42_POLARITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_42_POLARITY	Default"}
if {[lsearch -exact $props CONFIG.PSU_MIO_42_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_42_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_42_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_42_SLEW	fast"}
if {[lsearch -exact $props CONFIG.PSU_MIO_43_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_43_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_43_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_43_INPUT_TYPE	cmos"}
if {[lsearch -exact $props CONFIG.PSU_MIO_43_POLARITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_43_POLARITY	Default"}
if {[lsearch -exact $props CONFIG.PSU_MIO_43_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_43_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_43_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_43_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_44_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_44_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_44_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_44_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_44_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_44_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_45_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_45_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_45_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_45_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_46_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_46_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_46_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_46_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_46_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_46_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_46_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_46_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_47_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_47_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_47_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_47_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_47_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_47_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_47_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_47_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_48_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_48_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_48_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_48_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_48_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_48_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_48_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_48_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_49_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_49_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_49_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_49_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_49_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_49_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_49_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_49_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_4_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_4_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_4_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_4_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_4_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_4_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_4_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_4_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_50_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_50_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_50_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_50_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_50_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_50_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_50_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_50_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_51_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_51_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_51_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_51_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_51_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_51_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_52_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_52_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_52_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_52_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_53_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_53_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_53_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_53_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_54_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_54_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_54_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_54_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_54_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_54_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_54_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_54_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_55_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_55_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_55_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_55_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_56_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_56_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_56_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_56_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_56_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_56_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_56_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_56_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_57_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_57_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_57_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_57_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_57_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_57_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_57_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_57_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_58_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_58_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_58_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_58_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_58_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_58_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_59_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_59_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_59_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_59_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_59_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_59_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_59_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_59_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_5_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_5_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_5_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_5_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_5_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_5_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_60_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_60_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_60_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_60_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_60_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_60_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_60_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_60_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_61_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_61_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_61_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_61_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_61_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_61_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_61_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_61_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_62_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_62_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_62_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_62_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_62_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_62_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_62_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_62_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_63_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_63_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_63_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_63_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_63_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_63_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_63_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_63_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_64_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_64_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_64_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_64_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_64_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_64_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_65_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_65_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_65_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_65_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_65_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_65_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_66_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_66_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_66_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_66_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_66_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_66_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_67_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_67_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_67_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_67_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_67_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_67_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_68_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_68_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_68_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_68_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_68_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_68_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_69_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_69_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_69_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_69_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_69_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_69_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_6_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_6_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_6_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_6_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_6_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_6_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_70_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_70_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_70_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_70_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_71_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_71_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_71_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_71_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_72_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_72_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_72_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_72_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_73_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_73_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_73_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_73_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_74_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_74_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_74_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_74_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_75_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_75_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_75_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_75_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_76_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_76_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_76_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_76_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_76_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_76_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_77_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_77_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_77_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_77_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_77_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_77_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_77_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_77_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_7_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_7_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_7_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_7_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_7_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_7_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_8_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_8_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_8_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_8_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_8_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_8_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_8_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_8_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_9_DRIVE_STRENGTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_9_DRIVE_STRENGTH	12"}
if {[lsearch -exact $props CONFIG.PSU_MIO_9_INPUT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_9_INPUT_TYPE	schmitt"}
if {[lsearch -exact $props CONFIG.PSU_MIO_9_PULLUPDOWN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_9_PULLUPDOWN	pullup"}
if {[lsearch -exact $props CONFIG.PSU_MIO_9_SLEW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_9_SLEW	slow"}
if {[lsearch -exact $props CONFIG.PSU_MIO_TREE_PERIPHERALS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_TREE_PERIPHERALS	Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Feedback Clk#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0###GPIO1 MIO#DPAUX#DPAUX#DPAUX#DPAUX#GPIO1 MIO#UART 1#UART 1#CAN 0#CAN 0#GPIO1 MIO#PCIE#UART 0#UART 0#CAN 1#CAN 1#GPIO1 MIO#GPIO1 MIO#USB0 Reset#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#MDIO 3#MDIO 3"}
if {[lsearch -exact $props CONFIG.PSU_MIO_TREE_SIGNALS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_MIO_TREE_SIGNALS	sclk_out#miso_mo1#mo2#mo3#mosi_mi0#n_ss_out#clk_for_lpbk#n_ss_out_upper#mo_upper[0]#mo_upper[1]#mo_upper[2]#mo_upper[3]#sclk_out_upper#sdio0_data_out[0]#sdio0_data_out[1]#sdio0_data_out[2]#sdio0_data_out[3]#sdio0_data_out[4]#sdio0_data_out[5]#sdio0_data_out[6]#sdio0_data_out[7]#sdio0_cmd_out#sdio0_clk_out#sdio0_bus_pow###gpio1[26]#dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in#gpio1[31]#txd#rxd#phy_rx#phy_tx#gpio1[36]#reset_n#rxd#txd#phy_tx#phy_rx#gpio1[42]#gpio1[43]#reset#sdio1_cd_n#sdio1_data_out[0]#sdio1_data_out[1]#sdio1_data_out[2]#sdio1_data_out[3]#sdio1_cmd_out#sdio1_clk_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem3_mdc#gem3_mdio_out"}
if {[lsearch -exact $props CONFIG.PSU_SD0_INTERNAL_BUS_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SD0_INTERNAL_BUS_WIDTH	8"}
if {[lsearch -exact $props CONFIG.PSU_SD1_INTERNAL_BUS_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SD1_INTERNAL_BUS_WIDTH	4"}
if {[lsearch -exact $props CONFIG.PSU_SMC_CYCLE_T0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SMC_CYCLE_T0	NA"}
if {[lsearch -exact $props CONFIG.PSU_SMC_CYCLE_T1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SMC_CYCLE_T1	NA"}
if {[lsearch -exact $props CONFIG.PSU_SMC_CYCLE_T2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SMC_CYCLE_T2	NA"}
if {[lsearch -exact $props CONFIG.PSU_SMC_CYCLE_T3] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SMC_CYCLE_T3	NA"}
if {[lsearch -exact $props CONFIG.PSU_SMC_CYCLE_T4] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SMC_CYCLE_T4	NA"}
if {[lsearch -exact $props CONFIG.PSU_SMC_CYCLE_T5] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SMC_CYCLE_T5	NA"}
if {[lsearch -exact $props CONFIG.PSU_SMC_CYCLE_T6] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_SMC_CYCLE_T6	NA"}
if {[lsearch -exact $props CONFIG.PSU_USB3__DUAL_CLOCK_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_USB3__DUAL_CLOCK_ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU_VALUE_SILVERSION] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU_VALUE_SILVERSION	3"}
if {[lsearch -exact $props CONFIG.PSU__ACPU0__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ACPU0__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__ACPU1__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ACPU1__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__ACPU2__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ACPU2__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__ACPU3__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ACPU3__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__ACTUAL__IP] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ACTUAL__IP	1"}
if {[lsearch -exact $props CONFIG.PSU__ACT_DDR_FREQ_MHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ACT_DDR_FREQ_MHZ	1200.000000"}
if {[lsearch -exact $props CONFIG.PSU__AUX_REF_CLK__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__AUX_REF_CLK__FREQMHZ	33.333"}
if {[lsearch -exact $props CONFIG.PSU__CAN0_LOOP_CAN1__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CAN0_LOOP_CAN1__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CAN0__GRP_CLK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CAN0__GRP_CLK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CAN0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CAN0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__CAN0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CAN0__PERIPHERAL__IO	MIO 34 .. 35"}
if {[lsearch -exact $props CONFIG.PSU__CAN1__GRP_CLK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CAN1__GRP_CLK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CAN1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CAN1__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__CAN1__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CAN1__PERIPHERAL__IO	MIO 40 .. 41"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ	1333.333252"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__ACPU_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__ACPU_CTRL__FREQMHZ	1334"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__ACPU_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__ACPU_CTRL__SRCSEL	APLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__ACPU__FRAC_ENABLED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__ACPU__FRAC_ENABLED	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI0_REF_CTRL__ACT_FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI0_REF_CTRL__DIVISOR0	2"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI0_REF_CTRL__FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI0_REF_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI0_REF__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI0_REF__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI1_REF_CTRL__ACT_FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI1_REF_CTRL__DIVISOR0	2"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI1_REF_CTRL__FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI1_REF_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI1_REF__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI1_REF__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI2_REF_CTRL__ACT_FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI2_REF_CTRL__DIVISOR0	2"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI2_REF_CTRL__FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI2_REF_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI2_REF__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI2_REF__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI3_REF_CTRL__ACT_FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI3_REF_CTRL__DIVISOR0	2"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI3_REF_CTRL__FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI3_REF_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI3_REF__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI3_REF__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI4_REF_CTRL__ACT_FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI4_REF_CTRL__DIVISOR0	2"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI4_REF_CTRL__FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI4_REF_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI4_REF__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI4_REF__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI5_REF_CTRL__ACT_FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI5_REF_CTRL__DIVISOR0	2"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI5_REF_CTRL__FREQMHZ	667"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI5_REF_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__AFI5_REF__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__AFI5_REF__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__APLL_CTRL__FRACFREQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__APLL_CTRL__FRACFREQ	27.138"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__APLL_CTRL__SRCSEL	PSS_REF_CLK"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__APM_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__APM_CTRL__ACT_FREQMHZ	1"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__APM_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__APM_CTRL__DIVISOR0	1"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__APM_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__APM_CTRL__FREQMHZ	1"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ	250.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_TRACE_CTRL__ACT_FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ	250.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ	600.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DDR_CTRL__FREQMHZ	1200"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DDR_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ	600.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ	600"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DPLL_CTRL__FRACFREQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DPLL_CTRL__FRACFREQ	27.138"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DPLL_CTRL__SRCSEL	PSS_REF_CLK"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ	25.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ	25"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL	RPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ	26.666666"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ	27"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL	RPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ	300.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ	300"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL	VPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED	0"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ	600.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ	600"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL	DPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ	500.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ	500"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GPU_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GTGREF0_REF_CTRL__ACT_FREQMHZ	-1"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GTGREF0_REF_CTRL__DIVISOR0	-1"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GTGREF0_REF_CTRL__FREQMHZ	-1"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GTGREF0_REF_CTRL__SRCSEL	NA"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__GTGREF0__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__GTGREF0__ENABLE	NA"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__PCIE_REF_CTRL__ACT_FREQMHZ	250.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__PCIE_REF_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__PCIE_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ	444.444427"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ	533.33"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL	APLL"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACFREQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__VPLL_CTRL__FRACFREQ	27.138"}
if {[lsearch -exact $props CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRF_APB__VPLL_CTRL__SRCSEL	PSS_REF_CLK"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ	500.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ	500"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__AFI6_REF_CTRL__ACT_FREQMHZ	500"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__AFI6_REF_CTRL__FREQMHZ	500"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__AFI6_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__AFI6__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__AFI6__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ	50.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__AMS_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__AMS_REF_CTRL__FREQMHZ	50"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__AMS_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__AMS_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CAN0_REF_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CAN0_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CAN0_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CAN1_REF_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CAN1_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CAN1_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ	500.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ	500"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CPU_R5_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CSU_PLL_CTRL__ACT_FREQMHZ	180"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CSU_PLL_CTRL__DIVISOR0	3"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__CSU_PLL_CTRL__SRCSEL	SysOsc"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ	250.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__ACT_FREQMHZ	1000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__DIVISOR0	6"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__FREQMHZ	1000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__SRCSEL	RPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ	1500.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DLL_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DLL_REF_CTRL__FREQMHZ	1500"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__DLL_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__DLL_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM0_REF_CTRL__ACT_FREQMHZ	125.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ	125"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ	125"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ	125"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM2_REF_CTRL__ACT_FREQMHZ	125"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM2_REF_CTRL__FREQMHZ	125"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM2_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ	125.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ	125"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ	250.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__I2C0_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__I2C0_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__IOPLL_CTRL__FRACFREQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__IOPLL_CTRL__FRACFREQ	27.138"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__IOPLL_CTRL__SRCSEL	PSS_REF_CLK"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ	250.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ	500.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ	500"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__NAND_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__NAND_REF_CTRL__ACT_FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__NAND_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__NAND_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__NAND_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__NAND_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__OCM_MAIN_CTRL__ACT_FREQMHZ	500"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__DIVISOR0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__OCM_MAIN_CTRL__DIVISOR0	3"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__OCM_MAIN_CTRL__FREQMHZ	500"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__OCM_MAIN_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ	187.500000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PCAP_CTRL__FREQMHZ	200"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PCAP_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ	200.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ	200"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PL0_REF_CTRL__SRCSEL	RPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PL1_REF_CTRL__SRCSEL	RPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PL2_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PL2_REF_CTRL__ACT_FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__PL3_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__PL3_REF_CTRL__ACT_FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ	125.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ	125"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACFREQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__RPLL_CTRL__FRACFREQ	27.138"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__RPLL_CTRL__SRCSEL	PSS_REF_CLK"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ	187.500000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SDIO0_REF_CTRL__FREQMHZ	200"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SDIO0_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ	187.500000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ	200"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SPI0_REF_CTRL__ACT_FREQMHZ	200.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SPI0_REF_CTRL__FREQMHZ	200"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SPI0_REF_CTRL__SRCSEL	RPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ	214"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ	200"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL	RPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__UART0_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__UART1_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ	250.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ	250"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ	20.000000"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ	20"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL	IOPLL"}
if {[lsearch -exact $props CONFIG.PSU__CRL_APB__USB3__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CRL_APB__USB3__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__CSUPMU__PERIPHERAL__VALID] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSUPMU__PERIPHERAL__VALID	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_0__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_0__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_10__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_10__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_11__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_11__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_12__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_12__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_1__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_1__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_2__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_2__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_3__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_3__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_4__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_4__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_5__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_5__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_6__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_6__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_7__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_7__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_8__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_8__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__CSU_TAMPER_9__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__CSU_TAMPER_9__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__CSU__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__CSU__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__AL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__AL	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__BG_ADDR_COUNT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__BG_ADDR_COUNT	1"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__BRC_MAPPING] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__BRC_MAPPING	ROW_BANK_COL"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__BUS_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__BUS_WIDTH	64 Bit"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__CL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__CL	16"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__CLOCK_STOP_EN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__CLOCK_STOP_EN	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__COMPONENTS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__COMPONENTS	Components"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__CWL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__CWL	16"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DDR4_ADDR_MAPPING	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DDR4_CAL_MODE_ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DDR4_CRC_CONTROL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DDR4_CRC_CONTROL	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DDR4_MAXPWR_SAVING_EN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DDR4_MAXPWR_SAVING_EN	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DDR4_T_REF_MODE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DDR4_T_REF_MODE	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DDR4_T_REF_RANGE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DDR4_T_REF_RANGE	Normal (0-85)"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DEVICE_CAPACITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DEVICE_CAPACITY	16384 MBits"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DM_DBI] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DM_DBI	DM_NO_DBI"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__DRAM_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__DRAM_WIDTH	16 Bits"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__ECC] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__ECC	Disabled"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__ECC_SCRUB] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__ECC_SCRUB	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__ENABLE_2T_TIMING] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__ENABLE_2T_TIMING	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__ENABLE_DP_SWITCH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__ENABLE_DP_SWITCH	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__EN_2ND_CLK] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__EN_2ND_CLK	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__FGRM] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__FGRM	1X"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__FREQ_MHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__FREQ_MHZ	1"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__LPDDR3_DUALRANK_SDP] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__LPDDR3_DUALRANK_SDP	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__LP_ASR] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__LP_ASR	manual normal"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__MEMORY_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__MEMORY_TYPE	DDR 4"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__PARITY_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__PARITY_ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__PER_BANK_REFRESH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__PER_BANK_REFRESH	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__PHY_DBI_MODE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__PHY_DBI_MODE	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__PLL_BYPASS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__PLL_BYPASS	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__PWR_DOWN_EN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__PWR_DOWN_EN	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__RANK_ADDR_COUNT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__RANK_ADDR_COUNT	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__RD_DQS_CENTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__RD_DQS_CENTER	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__ROW_ADDR_COUNT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__ROW_ADDR_COUNT	17"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__SELF_REF_ABORT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__SELF_REF_ABORT	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__SPEED_BIN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__SPEED_BIN	DDR4_2400P"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__STATIC_RD_MODE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__STATIC_RD_MODE	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__TRAIN_DATA_EYE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__TRAIN_DATA_EYE	1"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__TRAIN_READ_GATE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__TRAIN_READ_GATE	1"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__TRAIN_WRITE_LEVEL	1"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__T_FAW] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__T_FAW	30.0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__T_RAS_MIN] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__T_RAS_MIN	32"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__T_RC] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__T_RC	45.32"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__T_RCD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__T_RCD	16"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__T_RP] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__T_RP	16"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__VIDEO_BUFFER_SIZE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__VIDEO_BUFFER_SIZE	0"}
if {[lsearch -exact $props CONFIG.PSU__DDRC__VREF] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDRC__VREF	1"}
if {[lsearch -exact $props CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDR_HIGH_ADDRESS_GUI_ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__DDR_QOS_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDR_QOS_ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__DDR_SW_REFRESH_ENABLED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDR_SW_REFRESH_ENABLED	1"}
if {[lsearch -exact $props CONFIG.PSU__DDR__INTERFACE__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DDR__INTERFACE__FREQMHZ	600.000"}
if {[lsearch -exact $props CONFIG.PSU__DEVICE_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DEVICE_TYPE	EG"}
if {[lsearch -exact $props CONFIG.PSU__DISPLAYPORT__LANE0__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DISPLAYPORT__LANE0__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__DISPLAYPORT__LANE0__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DISPLAYPORT__LANE0__IO	GT Lane3"}
if {[lsearch -exact $props CONFIG.PSU__DISPLAYPORT__LANE1__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DISPLAYPORT__LANE1__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__DISPLAYPORT__LANE1__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DISPLAYPORT__LANE1__IO	GT Lane2"}
if {[lsearch -exact $props CONFIG.PSU__DISPLAYPORT__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DISPLAYPORT__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__DLL__ISUSED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DLL__ISUSED	1"}
if {[lsearch -exact $props CONFIG.PSU__DPAUX__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DPAUX__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__DPAUX__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DPAUX__PERIPHERAL__IO	MIO 27 .. 30"}
if {[lsearch -exact $props CONFIG.PSU__DP__LANE_SEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DP__LANE_SEL	Dual Higher"}
if {[lsearch -exact $props CONFIG.PSU__DP__REF_CLK_FREQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DP__REF_CLK_FREQ	27"}
if {[lsearch -exact $props CONFIG.PSU__DP__REF_CLK_SEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__DP__REF_CLK_SEL	Ref Clk2"}
if {[lsearch -exact $props CONFIG.PSU__ENABLE__DDR__REFRESH__SIGNALS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENABLE__DDR__REFRESH__SIGNALS	0"}
if {[lsearch -exact $props CONFIG.PSU__ENET0__FIFO__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET0__FIFO__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__ENET0__GRP_MDIO__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET0__GRP_MDIO__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__ENET0__GRP_MDIO__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET0__GRP_MDIO__IO	EMIO"}
if {[lsearch -exact $props CONFIG.PSU__ENET0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__ENET0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET0__PERIPHERAL__IO	EMIO"}
if {[lsearch -exact $props CONFIG.PSU__ENET0__PTP__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET0__PTP__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__ENET1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET1__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__ENET2__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET2__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__ENET3__FIFO__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET3__FIFO__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__ENET3__GRP_MDIO__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET3__GRP_MDIO__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__ENET3__GRP_MDIO__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET3__GRP_MDIO__IO	MIO 76 .. 77"}
if {[lsearch -exact $props CONFIG.PSU__ENET3__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET3__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__ENET3__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET3__PERIPHERAL__IO	MIO 64 .. 75"}
if {[lsearch -exact $props CONFIG.PSU__ENET3__PTP__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET3__PTP__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__ENET3__TSU__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__ENET3__TSU__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__EN_AXI_STATUS_PORTS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__EN_AXI_STATUS_PORTS	0"}
if {[lsearch -exact $props CONFIG.PSU__EN_EMIO_TRACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__EN_EMIO_TRACE	0"}
if {[lsearch -exact $props CONFIG.PSU__EP__IP] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__EP__IP	0"}
if {[lsearch -exact $props CONFIG.PSU__EXPAND__CORESIGHT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__EXPAND__CORESIGHT	0"}
if {[lsearch -exact $props CONFIG.PSU__EXPAND__FPD_SLAVES] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__EXPAND__FPD_SLAVES	0"}
if {[lsearch -exact $props CONFIG.PSU__EXPAND__GIC] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__EXPAND__GIC	0"}
if {[lsearch -exact $props CONFIG.PSU__EXPAND__LOWER_LPS_SLAVES] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__EXPAND__LOWER_LPS_SLAVES	0"}
if {[lsearch -exact $props CONFIG.PSU__EXPAND__UPPER_LPS_SLAVES] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__EXPAND__UPPER_LPS_SLAVES	0"}
if {[lsearch -exact $props CONFIG.PSU__FPDMASTERS_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FPDMASTERS_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FPD_SLCR__WDT1__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__FPGA_PL0_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FPGA_PL0_ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__FPGA_PL1_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FPGA_PL1_ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__FPGA_PL2_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FPGA_PL2_ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__FPGA_PL3_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FPGA_PL3_ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__FP__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FP__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__FTM__CTI_IN_0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__CTI_IN_0	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__CTI_IN_1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__CTI_IN_1	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__CTI_IN_2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__CTI_IN_2	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__CTI_IN_3] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__CTI_IN_3	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__CTI_OUT_0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__CTI_OUT_0	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__CTI_OUT_1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__CTI_OUT_1	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__CTI_OUT_2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__CTI_OUT_2	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__CTI_OUT_3] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__CTI_OUT_3	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__GPI] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__GPI	0"}
if {[lsearch -exact $props CONFIG.PSU__FTM__GPO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__FTM__GPO	0"}
if {[lsearch -exact $props CONFIG.PSU__GEM0_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEM0_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__GEM0_ROUTE_THROUGH_FPD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEM0_ROUTE_THROUGH_FPD	0"}
if {[lsearch -exact $props CONFIG.PSU__GEM3_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEM3_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__GEM3_ROUTE_THROUGH_FPD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEM3_ROUTE_THROUGH_FPD	0"}
if {[lsearch -exact $props CONFIG.PSU__GEM__TSU__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEM__TSU__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_0__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_0__MASTER	APU"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_10__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_10__MASTER	NONE"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_1__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_1__MASTER	RPU0"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_2__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_2__MASTER	RPU1"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_3__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_3__MASTER	PMU"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_4__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_4__MASTER	PMU"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_5__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_5__MASTER	PMU"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_6__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_6__MASTER	PMU"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_7__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_7__MASTER	NONE"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_8__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_8__MASTER	NONE"}
if {[lsearch -exact $props CONFIG.PSU__GEN_IPI_9__MASTER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GEN_IPI_9__MASTER	NONE"}
if {[lsearch -exact $props CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPIO0_MIO__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__GPIO1_MIO__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPIO1_MIO__IO	MIO 26 .. 51"}
if {[lsearch -exact $props CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPIO1_MIO__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__GPIO2_MIO__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPIO2_MIO__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__GPIO_EMIO_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPIO_EMIO_WIDTH	95"}
if {[lsearch -exact $props CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPIO_EMIO__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPIO_EMIO__PERIPHERAL__IO	95"}
if {[lsearch -exact $props CONFIG.PSU__GPIO_EMIO__WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPIO_EMIO__WIDTH	[94:0]"}
if {[lsearch -exact $props CONFIG.PSU__GPU_PP0__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPU_PP0__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__GPU_PP1__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GPU_PP1__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__GT_REF_CLK__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GT_REF_CLK__FREQMHZ	33.333"}
if {[lsearch -exact $props CONFIG.PSU__GT__LINK_SPEED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GT__LINK_SPEED	HBR"}
if {[lsearch -exact $props CONFIG.PSU__GT__PRE_EMPH_LVL_4] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GT__PRE_EMPH_LVL_4	0"}
if {[lsearch -exact $props CONFIG.PSU__GT__VLT_SWNG_LVL_4] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__GT__VLT_SWNG_LVL_4	0"}
if {[lsearch -exact $props CONFIG.PSU__HPM0_FPD__NUM_READ_THREADS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__HPM0_FPD__NUM_READ_THREADS	4"}
if {[lsearch -exact $props CONFIG.PSU__HPM0_FPD__NUM_WRITE_THREADS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__HPM0_FPD__NUM_WRITE_THREADS	4"}
if {[lsearch -exact $props CONFIG.PSU__HPM0_LPD__NUM_READ_THREADS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__HPM0_LPD__NUM_READ_THREADS	4"}
if {[lsearch -exact $props CONFIG.PSU__HPM0_LPD__NUM_WRITE_THREADS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__HPM0_LPD__NUM_WRITE_THREADS	4"}
if {[lsearch -exact $props CONFIG.PSU__HPM1_FPD__NUM_READ_THREADS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__HPM1_FPD__NUM_READ_THREADS	4"}
if {[lsearch -exact $props CONFIG.PSU__HPM1_FPD__NUM_WRITE_THREADS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__HPM1_FPD__NUM_WRITE_THREADS	4"}
if {[lsearch -exact $props CONFIG.PSU__I2C0_LOOP_I2C1__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__I2C0_LOOP_I2C1__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__I2C0__GRP_INT__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__I2C0__GRP_INT__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__I2C0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__I2C0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__I2C0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__I2C0__PERIPHERAL__IO	EMIO"}
if {[lsearch -exact $props CONFIG.PSU__I2C1__GRP_INT__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__I2C1__GRP_INT__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__I2C1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__I2C1__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__I2C1__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__I2C1__PERIPHERAL__IO	EMIO"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC0_SEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC0_SEL	APB"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC1_SEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC1_SEL	APB"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC2_SEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC2_SEL	APB"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC3_SEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC3_SEL	APB"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__TTC0__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__TTC0__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__TTC1__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__TTC1__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__TTC2__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__TTC2__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__TTC3__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__TTC3__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__IOU_SLCR__WDT0__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IOU_SLCR__WDT0__ACT_FREQMHZ	100.000000"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_ADMA_CHAN__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_ADMA_CHAN__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_AIB_AXI__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_AIB_AXI__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_AMS__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_AMS__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APM_FPD__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APM_FPD__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APU_COMM__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APU_COMM__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APU_CPUMNT__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APU_CPUMNT__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APU_CTI__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APU_CTI__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APU_EXTERR__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APU_EXTERR__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APU_IPI__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APU_IPI__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APU_L2ERR__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APU_L2ERR__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APU_PMU__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APU_PMU__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_APU_REGS__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_APU_REGS__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_ATB_LPD__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_ATB_LPD__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_CAN0__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_CAN0__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_CAN1__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_CAN1__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_CLKMON__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_CLKMON__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_DDR_SS__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_DDR_SS__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_DPDMA__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_DPDMA__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_DPORT__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_DPORT__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_EFUSE__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_EFUSE__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_ENT0_WAKEUP__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_ENT0_WAKEUP__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_ENT0__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_ENT0__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_ENT3_WAKEUP__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_ENT3_WAKEUP__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_ENT3__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_ENT3__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_FPD_APB__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_FPD_APB__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_FPD_ATB_ERR__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_FPD_ATB_ERR__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_FP_WDT__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_FP_WDT__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_GDMA_CHAN__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_GDMA_CHAN__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_GPIO__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_GPIO__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_GPU__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_GPU__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_I2C0__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_I2C0__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_I2C1__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_I2C1__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_LPD_APB__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_LPD_APB__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_LPD_APM__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_LPD_APM__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_LP_WDT__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_LP_WDT__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_OCM_ERR__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_OCM_ERR__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_PCIE_DMA__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_PCIE_DMA__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_PCIE_LEGACY__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_PCIE_LEGACY__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_PCIE_MSC__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_PCIE_MSC__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_PCIE_MSI__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_PCIE_MSI__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_PL_IPI__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_PL_IPI__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_QSPI__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_QSPI__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_R5_CORE0_ECC_ERR__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_R5_CORE0_ECC_ERR__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_R5_CORE1_ECC_ERR__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_R5_CORE1_ECC_ERR__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_RPU_IPI__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_RPU_IPI__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_RPU_PERMON__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_RPU_PERMON__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_RTC_ALARM__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_RTC_ALARM__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_RTC_SECONDS__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_RTC_SECONDS__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_SATA__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_SATA__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_SDIO0_WAKE__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_SDIO0_WAKE__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_SDIO0__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_SDIO0__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_SDIO1_WAKE__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_SDIO1_WAKE__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_SDIO1__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_SDIO1__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC0__INT0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC0__INT0	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC0__INT1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC0__INT1	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC0__INT2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC0__INT2	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC1__INT0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC1__INT0	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC1__INT1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC1__INT1	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC1__INT2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC1__INT2	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC2__INT0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC2__INT0	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC2__INT1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC2__INT1	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC2__INT2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC2__INT2	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC3__INT0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC3__INT0	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC3__INT1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC3__INT1	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_TTC3__INT2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_TTC3__INT2	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_UART0__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_UART0__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_UART1__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_UART1__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_USB3_ENDPOINT__INT0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_USB3_ENDPOINT__INT0	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_USB3_ENDPOINT__INT1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_USB3_ENDPOINT__INT1	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_USB3_OTG__INT0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_USB3_OTG__INT0	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_USB3_OTG__INT1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_USB3_OTG__INT1	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_USB3_PMU_WAKEUP__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_USB3_PMU_WAKEUP__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_XMPU_FPD__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_XMPU_FPD__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F_XMPU_LPD__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F_XMPU_LPD__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F__INTF_FPD_SMMU__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F__INTF_FPD_SMMU__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__IRQ_P2F__INTF_PPD_CCI__INT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__IRQ_P2F__INTF_PPD_CCI__INT	0"}
if {[lsearch -exact $props CONFIG.PSU__L2_BANK0__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__L2_BANK0__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__LPDMA0_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPDMA0_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__LPDMA1_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPDMA1_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__LPDMA2_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPDMA2_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__LPDMA3_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPDMA3_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__LPDMA4_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPDMA4_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__LPDMA5_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPDMA5_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__LPDMA6_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPDMA6_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__LPDMA7_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPDMA7_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__LPD_SLCR__CSUPMU_WDT_CLK_SEL__SELECT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPD_SLCR__CSUPMU_WDT_CLK_SEL__SELECT	APB"}
if {[lsearch -exact $props CONFIG.PSU__LPD_SLCR__CSUPMU__ACT_FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPD_SLCR__CSUPMU__ACT_FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__LPD_SLCR__CSUPMU__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__LPD_SLCR__CSUPMU__FREQMHZ	100"}
if {[lsearch -exact $props CONFIG.PSU__MAXIGP0__DATA_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__MAXIGP0__DATA_WIDTH	128"}
if {[lsearch -exact $props CONFIG.PSU__M_AXI_GP0_SUPPORTS_NARROW_BURST] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__M_AXI_GP0_SUPPORTS_NARROW_BURST	1"}
if {[lsearch -exact $props CONFIG.PSU__M_AXI_GP1_SUPPORTS_NARROW_BURST] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__M_AXI_GP1_SUPPORTS_NARROW_BURST	1"}
if {[lsearch -exact $props CONFIG.PSU__M_AXI_GP2_SUPPORTS_NARROW_BURST] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__M_AXI_GP2_SUPPORTS_NARROW_BURST	1"}
if {[lsearch -exact $props CONFIG.PSU__NAND__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__NAND__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__NAND__READY_BUSY__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__NAND__READY_BUSY__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__NUM_FABRIC_RESETS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__NUM_FABRIC_RESETS	1"}
if {[lsearch -exact $props CONFIG.PSU__OCM_BANK0__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__OCM_BANK0__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__OCM_BANK1__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__OCM_BANK1__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__OCM_BANK2__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__OCM_BANK2__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__OCM_BANK3__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__OCM_BANK3__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__OVERRIDE_HPX_QOS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__OVERRIDE_HPX_QOS	0"}
if {[lsearch -exact $props CONFIG.PSU__OVERRIDE__BASIC_CLOCK] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__OVERRIDE__BASIC_CLOCK	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__ACS_VIOLAION] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__ACS_VIOLAION	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__AER_CAPABILITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__AER_CAPABILITY	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR0_64BIT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR0_64BIT	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR0_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR0_ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR0_PREFETCHABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR0_PREFETCHABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR0_SCALE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR0_SCALE	Megabytes"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR0_SIZE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR0_SIZE	1"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR0_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR0_TYPE	Memory"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR0_VAL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR0_VAL	0xfff00000"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR1_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR1_ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR1_VAL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR1_VAL	0x0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR2_VAL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR2_VAL	0x0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR3_VAL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR3_VAL	0x0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR4_VAL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR4_VAL	0x0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__BAR5_VAL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__BAR5_VAL	0x0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__CLASS_CODE_BASE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__CLASS_CODE_BASE	0x06"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__CLASS_CODE_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__CLASS_CODE_INTERFACE	0x0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__CLASS_CODE_SUB] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__CLASS_CODE_SUB	0x04"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__CLASS_CODE_VALUE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__CLASS_CODE_VALUE	0x60400"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__CRS_SW_VISIBILITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__CRS_SW_VISIBILITY	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__DEVICE_ID] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__DEVICE_ID	0xD011"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__DEVICE_PORT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__DEVICE_PORT_TYPE	Root Port"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__EROM_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__EROM_ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__EROM_VAL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__EROM_VAL	0x0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__INTX_GENERATION] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__INTX_GENERATION	1"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__LANE0__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__LANE0__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__LANE0__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__LANE0__IO	GT Lane0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__LANE1__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__LANE1__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__LANE2__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__LANE2__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__LANE3__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__LANE3__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__LINK_SPEED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__LINK_SPEED	5.0 Gb/s"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__MAXIMUM_LINK_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__MAXIMUM_LINK_WIDTH	x1"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__MAX_PAYLOAD_SIZE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__MAX_PAYLOAD_SIZE	256 bytes"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__PERIPHERAL__ENDPOINT_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__PERIPHERAL__ENDPOINT_ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__PERIPHERAL__ROOTPORT_ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__PERIPHERAL__ROOTPORT_ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__PERIPHERAL__ROOTPORT_IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__PERIPHERAL__ROOTPORT_IO	MIO 37"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__REF_CLK_FREQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__REF_CLK_FREQ	100"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__REF_CLK_SEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__REF_CLK_SEL	Ref Clk0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__RESET__POLARITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__RESET__POLARITY	Active Low"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__REVISION_ID] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__REVISION_ID	0x0"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__SUBSYSTEM_ID] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__SUBSYSTEM_ID	0x7"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__SUBSYSTEM_VENDOR_ID] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__SUBSYSTEM_VENDOR_ID	0x10EE"}
if {[lsearch -exact $props CONFIG.PSU__PCIE__VENDOR_ID] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PCIE__VENDOR_ID	0x10EE"}
if {[lsearch -exact $props CONFIG.PSU__PJTAG__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PJTAG__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PL_CLK0_BUF] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PL_CLK0_BUF	TRUE"}
if {[lsearch -exact $props CONFIG.PSU__PL_CLK1_BUF] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PL_CLK1_BUF	TRUE"}
if {[lsearch -exact $props CONFIG.PSU__PL__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PL__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__PMU__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PMU__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PRESET_APPLIED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PRESET_APPLIED	1"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__DDR_SEGMENTS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__DDR_SEGMENTS	NONE"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__FPD_SEGMENTS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__FPD_SEGMENTS	SA:0xFD1A0000 ;SIZE:1280;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD000000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD010000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD020000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD030000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD040000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD050000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD610000 ;SIZE:512;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD5D0000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__LPD_SEGMENTS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__LPD_SEGMENTS	SA:0xFF980000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFF5E0000 ;SIZE:2560;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFFCC0000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFF180000 ;SIZE:768;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFF410000 ;SIZE:640;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFFA70000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFF9A0000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__MASTERS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__MASTERS	USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;1|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;1|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;1|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__MASTERS_TZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__MASTERS_TZ	GEM0:NonSecure|SD1:NonSecure|GEM2:NonSecure|GEM1:NonSecure|GEM3:NonSecure|PCIe:NonSecure|DP:NonSecure|NAND:NonSecure|GPU:NonSecure|USB1:NonSecure|USB0:NonSecure|LDMA:NonSecure|FDMA:NonSecure|QSPI:NonSecure|SD0:NonSecure"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__OCM_SEGMENTS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__OCM_SEGMENTS	NONE"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__PRESUBSYSTEMS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__PRESUBSYSTEMS	NONE"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__SLAVES] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__SLAVES	LPD;USB3_1_XHCI;FE300000;FE3FFFFF;0|LPD;USB3_1;FF9E0000;FF9EFFFF;0|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;1|LPD;UART0;FF000000;FF00FFFF;1|LPD;TTC3;FF140000;FF14FFFF;1|LPD;TTC2;FF130000;FF13FFFF;1|LPD;TTC1;FF120000;FF12FFFF;1|LPD;TTC0;FF110000;FF11FFFF;1|FPD;SWDT1;FD4D0000;FD4DFFFF;1|LPD;SWDT0;FF150000;FF15FFFF;1|LPD;SPI1;FF050000;FF05FFFF;0|LPD;SPI0;FF040000;FF04FFFF;0|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;1|LPD;SD0;FF160000;FF16FFFF;1|FPD;SATA;FD0C0000;FD0CFFFF;0|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;1|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;1|FPD;PCIE_LOW;E0000000;EFFFFFFF;1|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;1|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;1|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;1|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;1|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;1|FPD;GPU;FD4B0000;FD4BFFFF;1|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;1|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;0|LPD;GEM0;FF0B0000;FF0BFFFF;1|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display Port;FD4A0000;FD4AFFFF;1|FPD;DPDMA;FD4C0000;FD4CFFFF;1|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;97FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;1|LPD;CAN0;FF060000;FF06FFFF;1|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1"}
if {[lsearch -exact $props CONFIG.PSU__PROTECTION__SUBSYSTEMS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PROTECTION__SUBSYSTEMS	PMU Firmware:PMU"}
if {[lsearch -exact $props CONFIG.PSU__PSS_ALT_REF_CLK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PSS_ALT_REF_CLK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__PSS_ALT_REF_CLK__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PSS_ALT_REF_CLK__FREQMHZ	33.333"}
if {[lsearch -exact $props CONFIG.PSU__PSS_REF_CLK__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__PSS_REF_CLK__FREQMHZ	33.333333"}
if {[lsearch -exact $props CONFIG.PSU__QSPI_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__QSPI_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__QSPI_ROUTE_THROUGH_FPD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__QSPI_ROUTE_THROUGH_FPD	0"}
if {[lsearch -exact $props CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__QSPI__GRP_FBCLK__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__QSPI__GRP_FBCLK__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__QSPI__GRP_FBCLK__IO	MIO 6"}
if {[lsearch -exact $props CONFIG.PSU__QSPI__PERIPHERAL__DATA_MODE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__QSPI__PERIPHERAL__DATA_MODE	x4"}
if {[lsearch -exact $props CONFIG.PSU__QSPI__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__QSPI__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__QSPI__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__QSPI__PERIPHERAL__IO	MIO 0 .. 12"}
if {[lsearch -exact $props CONFIG.PSU__QSPI__PERIPHERAL__MODE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__QSPI__PERIPHERAL__MODE	Dual Parallel"}
if {[lsearch -exact $props CONFIG.PSU__REPORT__DBGLOG] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__REPORT__DBGLOG	0"}
if {[lsearch -exact $props CONFIG.PSU__RPU_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__RPU_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__RPU__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__RPU__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__SATA__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SATA__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SAXIGP3__DATA_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SAXIGP3__DATA_WIDTH	128"}
if {[lsearch -exact $props CONFIG.PSU__SD0_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__SD0_ROUTE_THROUGH_FPD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0_ROUTE_THROUGH_FPD	0"}
if {[lsearch -exact $props CONFIG.PSU__SD0__DATA_TRANSFER_MODE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0__DATA_TRANSFER_MODE	8Bit"}
if {[lsearch -exact $props CONFIG.PSU__SD0__GRP_POW__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0__GRP_POW__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__SD0__GRP_POW__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0__GRP_POW__IO	MIO 23"}
if {[lsearch -exact $props CONFIG.PSU__SD0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__SD0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0__PERIPHERAL__IO	MIO 13 .. 22"}
if {[lsearch -exact $props CONFIG.PSU__SD0__RESET__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0__RESET__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__SD0__SLOT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD0__SLOT_TYPE	eMMC"}
if {[lsearch -exact $props CONFIG.PSU__SD1_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__SD1_ROUTE_THROUGH_FPD] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1_ROUTE_THROUGH_FPD	0"}
if {[lsearch -exact $props CONFIG.PSU__SD1__DATA_TRANSFER_MODE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1__DATA_TRANSFER_MODE	4Bit"}
if {[lsearch -exact $props CONFIG.PSU__SD1__GRP_CD__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1__GRP_CD__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__SD1__GRP_CD__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1__GRP_CD__IO	MIO 45"}
if {[lsearch -exact $props CONFIG.PSU__SD1__GRP_POW__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1__GRP_POW__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SD1__GRP_WP__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1__GRP_WP__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SD1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__SD1__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1__PERIPHERAL__IO	MIO 46 .. 51"}
if {[lsearch -exact $props CONFIG.PSU__SD1__SLOT_TYPE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SD1__SLOT_TYPE	SD 2.0"}
if {[lsearch -exact $props CONFIG.PSU__SPI0_LOOP_SPI1__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SPI0_LOOP_SPI1__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SPI0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SPI0__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SPI1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SPI1__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SWDT0__CLOCK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SWDT0__CLOCK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SWDT0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__SWDT0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SWDT0__PERIPHERAL__IO	NA"}
if {[lsearch -exact $props CONFIG.PSU__SWDT0__RESET__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SWDT0__RESET__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SWDT1__CLOCK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SWDT1__CLOCK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SWDT1__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__SWDT1__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SWDT1__PERIPHERAL__IO	NA"}
if {[lsearch -exact $props CONFIG.PSU__SWDT1__RESET__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__SWDT1__RESET__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TCM0A__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TCM0A__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__TCM0B__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TCM0B__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__TCM1A__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TCM1A__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__TCM1B__POWER__ON] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TCM1B__POWER__ON	1"}
if {[lsearch -exact $props CONFIG.PSU__TESTSCAN__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TESTSCAN__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TRACE__INTERNAL_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TRACE__INTERNAL_WIDTH	32"}
if {[lsearch -exact $props CONFIG.PSU__TRACE__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TRACE__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TRISTATE__INVERTED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TRISTATE__INVERTED	1"}
if {[lsearch -exact $props CONFIG.PSU__TSU__BUFG_PORT_PAIR] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TSU__BUFG_PORT_PAIR	0"}
if {[lsearch -exact $props CONFIG.PSU__TTC0__CLOCK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC0__CLOCK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TTC0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__TTC0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC0__PERIPHERAL__IO	NA"}
if {[lsearch -exact $props CONFIG.PSU__TTC0__WAVEOUT__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC0__WAVEOUT__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TTC1__CLOCK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC1__CLOCK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TTC1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC1__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__TTC1__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC1__PERIPHERAL__IO	NA"}
if {[lsearch -exact $props CONFIG.PSU__TTC1__WAVEOUT__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC1__WAVEOUT__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TTC2__CLOCK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC2__CLOCK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TTC2__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC2__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__TTC2__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC2__PERIPHERAL__IO	NA"}
if {[lsearch -exact $props CONFIG.PSU__TTC2__WAVEOUT__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC2__WAVEOUT__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TTC3__CLOCK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC3__CLOCK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__TTC3__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC3__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__TTC3__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC3__PERIPHERAL__IO	NA"}
if {[lsearch -exact $props CONFIG.PSU__TTC3__WAVEOUT__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__TTC3__WAVEOUT__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__UART0_LOOP_UART1__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART0_LOOP_UART1__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__UART0__BAUD_RATE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART0__BAUD_RATE	115200"}
if {[lsearch -exact $props CONFIG.PSU__UART0__MODEM__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART0__MODEM__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__UART0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__UART0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART0__PERIPHERAL__IO	MIO 38 .. 39"}
if {[lsearch -exact $props CONFIG.PSU__UART1__BAUD_RATE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART1__BAUD_RATE	115200"}
if {[lsearch -exact $props CONFIG.PSU__UART1__MODEM__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART1__MODEM__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__UART1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART1__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__UART1__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__UART1__PERIPHERAL__IO	MIO 32 .. 33"}
if {[lsearch -exact $props CONFIG.PSU__USB0_COHERENCY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB0_COHERENCY	0"}
if {[lsearch -exact $props CONFIG.PSU__USB0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__USB0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB0__PERIPHERAL__IO	MIO 52 .. 63"}
if {[lsearch -exact $props CONFIG.PSU__USB0__REF_CLK_FREQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB0__REF_CLK_FREQ	26"}
if {[lsearch -exact $props CONFIG.PSU__USB0__REF_CLK_SEL] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB0__REF_CLK_SEL	Ref Clk1"}
if {[lsearch -exact $props CONFIG.PSU__USB0__RESET__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB0__RESET__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__USB0__RESET__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB0__RESET__IO	MIO 44"}
if {[lsearch -exact $props CONFIG.PSU__USB1__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB1__PERIPHERAL__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__USB1__RESET__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB1__RESET__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__USB2_0__EMIO__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB2_0__EMIO__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__USB3_0__EMIO__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB3_0__EMIO__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB3_0__PERIPHERAL__ENABLE	1"}
if {[lsearch -exact $props CONFIG.PSU__USB3_0__PERIPHERAL__IO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB3_0__PERIPHERAL__IO	GT Lane1"}
if {[lsearch -exact $props CONFIG.PSU__USB__RESET__MODE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB__RESET__MODE	Separate MIO Pin"}
if {[lsearch -exact $props CONFIG.PSU__USB__RESET__POLARITY] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USB__RESET__POLARITY	Active Low"}
if {[lsearch -exact $props CONFIG.PSU__USE_DIFF_RW_CLK_GP3] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE_DIFF_RW_CLK_GP3	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__ADMA] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__ADMA	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__APU_LEGACY_INTERRUPT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__APU_LEGACY_INTERRUPT	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__AUDIO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__AUDIO	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__CLK] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__CLK	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__CLK0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__CLK0	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__CLK1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__CLK1	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__CLK2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__CLK2	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__CLK3] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__CLK3	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__CROSS_TRIGGER] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__CROSS_TRIGGER	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__DDR_INTF_REQUESTED] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__DDR_INTF_REQUESTED	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__DEBUG__TEST] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__DEBUG__TEST	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__EVENT_RPU] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__EVENT_RPU	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__FABRIC__RST] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__FABRIC__RST	1"}
if {[lsearch -exact $props CONFIG.PSU__USE__FTM] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__FTM	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__GDMA] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__GDMA	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__IRQ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__IRQ	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__IRQ0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__IRQ0	1"}
if {[lsearch -exact $props CONFIG.PSU__USE__IRQ1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__IRQ1	1"}
if {[lsearch -exact $props CONFIG.PSU__USE__M_AXI_GP0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__M_AXI_GP0	1"}
if {[lsearch -exact $props CONFIG.PSU__USE__M_AXI_GP1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__M_AXI_GP1	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__M_AXI_GP2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__M_AXI_GP2	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__PROC_EVENT_BUS] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__PROC_EVENT_BUS	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__RPU_LEGACY_INTERRUPT] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__RPU_LEGACY_INTERRUPT	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__RST0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__RST0	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__RST1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__RST1	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__RST2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__RST2	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__RST3] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__RST3	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__RTC] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__RTC	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__STM] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__STM	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_ACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_ACE	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_ACP] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_ACP	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_GP0] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_GP0	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_GP1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_GP1	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_GP2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_GP2	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_GP3] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_GP3	1"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_GP4] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_GP4	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_GP5] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_GP5	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__S_AXI_GP6] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__S_AXI_GP6	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__USB3_0_HUB] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__USB3_0_HUB	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__USB3_1_HUB] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__USB3_1_HUB	0"}
if {[lsearch -exact $props CONFIG.PSU__USE__VIDEO] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__USE__VIDEO	0"}
if {[lsearch -exact $props CONFIG.PSU__VIDEO_REF_CLK__ENABLE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__VIDEO_REF_CLK__ENABLE	0"}
if {[lsearch -exact $props CONFIG.PSU__VIDEO_REF_CLK__FREQMHZ] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	PSU__VIDEO_REF_CLK__FREQMHZ	33.333"}
if {[lsearch -exact $props CONFIG.QSPI_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	QSPI_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.SATA_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SATA_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.SD0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SD0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.SD1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SD1_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.SPI0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SPI0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.SPI1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SPI1_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.SUBPRESET1] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SUBPRESET1	Custom"}
if {[lsearch -exact $props CONFIG.SUBPRESET2] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SUBPRESET2	Custom"}
if {[lsearch -exact $props CONFIG.SWDT0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SWDT0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.SWDT1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	SWDT1_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.TRACE_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	TRACE_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.TTC0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	TTC0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.TTC1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	TTC1_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.TTC2_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	TTC2_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.TTC3_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	TTC3_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.UART0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	UART0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.UART1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	UART1_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.USB0_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	USB0_BOARD_INTERFACE	custom"}
if {[lsearch -exact $props CONFIG.USB1_BOARD_INTERFACE] < 0} {incr unsupported; puts $audit "MISSING	zynq_ultra_ps_e_0	USB1_BOARD_INTERFACE	custom"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.CAN0_BOARD_INTERFACE {custom} CONFIG.CAN1_BOARD_INTERFACE {custom} CONFIG.CSU_BOARD_INTERFACE {custom} CONFIG.DP_BOARD_INTERFACE {custom} CONFIG.GEM0_BOARD_INTERFACE {custom} CONFIG.GEM1_BOARD_INTERFACE {custom} CONFIG.GEM2_BOARD_INTERFACE {custom} CONFIG.GEM3_BOARD_INTERFACE {custom} CONFIG.GPIO_BOARD_INTERFACE {custom} CONFIG.IIC0_BOARD_INTERFACE {custom} CONFIG.IIC1_BOARD_INTERFACE {custom} CONFIG.NAND_BOARD_INTERFACE {custom} CONFIG.PCIE_BOARD_INTERFACE {custom} CONFIG.PJTAG_BOARD_INTERFACE {custom} CONFIG.PMU_BOARD_INTERFACE {custom} CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS33} CONFIG.PSU_DDR_RAM_HIGHADDR {0x1FFFFFFFF} CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} CONFIG.PSU_MIO_0_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_0_PULLUPDOWN {pullup} CONFIG.PSU_MIO_0_SLEW {slow} CONFIG.PSU_MIO_10_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_10_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_10_PULLUPDOWN {pullup} CONFIG.PSU_MIO_10_SLEW {slow} CONFIG.PSU_MIO_11_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_11_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_11_PULLUPDOWN {pullup} CONFIG.PSU_MIO_11_SLEW {slow} CONFIG.PSU_MIO_12_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_12_PULLUPDOWN {pullup} CONFIG.PSU_MIO_12_SLEW {slow} CONFIG.PSU_MIO_13_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_13_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_13_PULLUPDOWN {pullup} CONFIG.PSU_MIO_13_SLEW {slow} CONFIG.PSU_MIO_14_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_14_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_14_PULLUPDOWN {pullup} CONFIG.PSU_MIO_14_SLEW {slow} CONFIG.PSU_MIO_15_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_15_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_15_PULLUPDOWN {pullup} CONFIG.PSU_MIO_15_SLEW {slow} CONFIG.PSU_MIO_16_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_16_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_16_PULLUPDOWN {pullup} CONFIG.PSU_MIO_16_SLEW {slow} CONFIG.PSU_MIO_17_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_17_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_17_PULLUPDOWN {pullup} CONFIG.PSU_MIO_17_SLEW {slow} CONFIG.PSU_MIO_18_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_18_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_18_PULLUPDOWN {pullup} CONFIG.PSU_MIO_18_SLEW {slow} CONFIG.PSU_MIO_19_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_19_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_19_PULLUPDOWN {pullup} CONFIG.PSU_MIO_19_SLEW {slow} CONFIG.PSU_MIO_1_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_1_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_1_PULLUPDOWN {pullup} CONFIG.PSU_MIO_1_SLEW {slow} CONFIG.PSU_MIO_20_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_20_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_20_PULLUPDOWN {pullup} CONFIG.PSU_MIO_20_SLEW {slow} CONFIG.PSU_MIO_21_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_21_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_21_PULLUPDOWN {pullup} CONFIG.PSU_MIO_21_SLEW {slow} CONFIG.PSU_MIO_22_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_22_PULLUPDOWN {pullup} CONFIG.PSU_MIO_22_SLEW {slow} CONFIG.PSU_MIO_23_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_23_PULLUPDOWN {pullup} CONFIG.PSU_MIO_23_SLEW {slow} CONFIG.PSU_MIO_24_DIRECTION {inout} CONFIG.PSU_MIO_24_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_24_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_24_PULLUPDOWN {pullup} CONFIG.PSU_MIO_24_SLEW {slow} CONFIG.PSU_MIO_25_DIRECTION {inout} CONFIG.PSU_MIO_25_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_25_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_25_PULLUPDOWN {pullup} CONFIG.PSU_MIO_25_SLEW {slow} CONFIG.PSU_MIO_26_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_26_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_26_POLARITY {Default} CONFIG.PSU_MIO_26_PULLUPDOWN {pullup} CONFIG.PSU_MIO_26_SLEW {slow} CONFIG.PSU_MIO_27_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_27_PULLUPDOWN {pullup} CONFIG.PSU_MIO_27_SLEW {slow} CONFIG.PSU_MIO_28_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_28_PULLUPDOWN {pullup} CONFIG.PSU_MIO_29_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_29_PULLUPDOWN {pullup} CONFIG.PSU_MIO_29_SLEW {slow} CONFIG.PSU_MIO_2_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_2_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_2_PULLUPDOWN {pullup} CONFIG.PSU_MIO_2_SLEW {slow} CONFIG.PSU_MIO_30_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_30_PULLUPDOWN {pullup} CONFIG.PSU_MIO_31_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_31_INPUT_TYPE {cmos} CONFIG.PSU_MIO_31_POLARITY {Default} CONFIG.PSU_MIO_31_PULLUPDOWN {pullup} CONFIG.PSU_MIO_31_SLEW {slow} CONFIG.PSU_MIO_32_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_32_PULLUPDOWN {pullup} CONFIG.PSU_MIO_32_SLEW {slow} CONFIG.PSU_MIO_33_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_33_PULLUPDOWN {pullup} CONFIG.PSU_MIO_34_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_34_PULLUPDOWN {pullup} CONFIG.PSU_MIO_35_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_35_PULLUPDOWN {pullup} CONFIG.PSU_MIO_35_SLEW {slow} CONFIG.PSU_MIO_36_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_36_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_36_POLARITY {Default} CONFIG.PSU_MIO_36_PULLUPDOWN {pullup} CONFIG.PSU_MIO_36_SLEW {slow} CONFIG.PSU_MIO_37_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_37_PULLUPDOWN {pullup} CONFIG.PSU_MIO_37_SLEW {fast} CONFIG.PSU_MIO_38_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_38_PULLUPDOWN {pullup} CONFIG.PSU_MIO_39_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_39_PULLUPDOWN {pullup} CONFIG.PSU_MIO_39_SLEW {slow} CONFIG.PSU_MIO_3_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_3_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_3_PULLUPDOWN {pullup} CONFIG.PSU_MIO_3_SLEW {slow} CONFIG.PSU_MIO_40_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_40_PULLUPDOWN {pullup} CONFIG.PSU_MIO_40_SLEW {slow} CONFIG.PSU_MIO_41_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_41_PULLUPDOWN {pullup} CONFIG.PSU_MIO_42_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_42_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_42_POLARITY {Default} CONFIG.PSU_MIO_42_PULLUPDOWN {pullup} CONFIG.PSU_MIO_42_SLEW {fast} CONFIG.PSU_MIO_43_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_43_INPUT_TYPE {cmos} CONFIG.PSU_MIO_43_POLARITY {Default} CONFIG.PSU_MIO_43_PULLUPDOWN {pullup} CONFIG.PSU_MIO_43_SLEW {slow} CONFIG.PSU_MIO_44_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_44_PULLUPDOWN {pullup} CONFIG.PSU_MIO_44_SLEW {slow} CONFIG.PSU_MIO_45_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_45_PULLUPDOWN {pullup} CONFIG.PSU_MIO_46_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_46_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_46_PULLUPDOWN {pullup} CONFIG.PSU_MIO_46_SLEW {slow} CONFIG.PSU_MIO_47_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_47_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_47_PULLUPDOWN {pullup} CONFIG.PSU_MIO_47_SLEW {slow} CONFIG.PSU_MIO_48_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_48_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_48_PULLUPDOWN {pullup} CONFIG.PSU_MIO_48_SLEW {slow} CONFIG.PSU_MIO_49_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_49_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_49_PULLUPDOWN {pullup} CONFIG.PSU_MIO_49_SLEW {slow} CONFIG.PSU_MIO_4_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_4_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_4_PULLUPDOWN {pullup} CONFIG.PSU_MIO_4_SLEW {slow} CONFIG.PSU_MIO_50_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_50_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_50_PULLUPDOWN {pullup} CONFIG.PSU_MIO_50_SLEW {slow} CONFIG.PSU_MIO_51_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_51_PULLUPDOWN {pullup} CONFIG.PSU_MIO_51_SLEW {slow} CONFIG.PSU_MIO_52_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_52_PULLUPDOWN {pullup} CONFIG.PSU_MIO_53_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_53_PULLUPDOWN {pullup} CONFIG.PSU_MIO_54_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_54_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_54_PULLUPDOWN {pullup} CONFIG.PSU_MIO_54_SLEW {slow} CONFIG.PSU_MIO_55_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_55_PULLUPDOWN {pullup} CONFIG.PSU_MIO_56_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_56_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_56_PULLUPDOWN {pullup} CONFIG.PSU_MIO_56_SLEW {slow} CONFIG.PSU_MIO_57_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_57_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_57_PULLUPDOWN {pullup} CONFIG.PSU_MIO_57_SLEW {slow} CONFIG.PSU_MIO_58_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_58_PULLUPDOWN {pullup} CONFIG.PSU_MIO_58_SLEW {slow} CONFIG.PSU_MIO_59_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_59_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_59_PULLUPDOWN {pullup} CONFIG.PSU_MIO_59_SLEW {slow} CONFIG.PSU_MIO_5_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_5_PULLUPDOWN {pullup} CONFIG.PSU_MIO_5_SLEW {slow} CONFIG.PSU_MIO_60_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_60_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_60_PULLUPDOWN {pullup} CONFIG.PSU_MIO_60_SLEW {slow} CONFIG.PSU_MIO_61_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_61_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_61_PULLUPDOWN {pullup} CONFIG.PSU_MIO_61_SLEW {slow} CONFIG.PSU_MIO_62_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_62_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_62_PULLUPDOWN {pullup} CONFIG.PSU_MIO_62_SLEW {slow} CONFIG.PSU_MIO_63_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_63_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_63_PULLUPDOWN {pullup} CONFIG.PSU_MIO_63_SLEW {slow} CONFIG.PSU_MIO_64_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_64_PULLUPDOWN {pullup} CONFIG.PSU_MIO_64_SLEW {slow} CONFIG.PSU_MIO_65_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_65_PULLUPDOWN {pullup} CONFIG.PSU_MIO_65_SLEW {slow} CONFIG.PSU_MIO_66_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_66_PULLUPDOWN {pullup} CONFIG.PSU_MIO_66_SLEW {slow} CONFIG.PSU_MIO_67_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_67_PULLUPDOWN {pullup} CONFIG.PSU_MIO_67_SLEW {slow} CONFIG.PSU_MIO_68_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_68_PULLUPDOWN {pullup} CONFIG.PSU_MIO_68_SLEW {slow} CONFIG.PSU_MIO_69_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_69_PULLUPDOWN {pullup} CONFIG.PSU_MIO_69_SLEW {slow} CONFIG.PSU_MIO_6_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_6_PULLUPDOWN {pullup} CONFIG.PSU_MIO_6_SLEW {slow} CONFIG.PSU_MIO_70_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_70_PULLUPDOWN {pullup} CONFIG.PSU_MIO_71_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_71_PULLUPDOWN {pullup} CONFIG.PSU_MIO_72_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_72_PULLUPDOWN {pullup} CONFIG.PSU_MIO_73_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_73_PULLUPDOWN {pullup} CONFIG.PSU_MIO_74_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_74_PULLUPDOWN {pullup} CONFIG.PSU_MIO_75_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_75_PULLUPDOWN {pullup} CONFIG.PSU_MIO_76_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_76_PULLUPDOWN {pullup} CONFIG.PSU_MIO_76_SLEW {slow} CONFIG.PSU_MIO_77_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_77_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_77_PULLUPDOWN {pullup} CONFIG.PSU_MIO_77_SLEW {slow} CONFIG.PSU_MIO_7_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_7_PULLUPDOWN {pullup} CONFIG.PSU_MIO_7_SLEW {slow} CONFIG.PSU_MIO_8_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_8_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_8_PULLUPDOWN {pullup} CONFIG.PSU_MIO_8_SLEW {slow} CONFIG.PSU_MIO_9_DRIVE_STRENGTH {12} CONFIG.PSU_MIO_9_INPUT_TYPE {schmitt} CONFIG.PSU_MIO_9_PULLUPDOWN {pullup} CONFIG.PSU_MIO_9_SLEW {slow} CONFIG.PSU_MIO_TREE_PERIPHERALS {Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Feedback Clk#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0###GPIO1 MIO#DPAUX#DPAUX#DPAUX#DPAUX#GPIO1 MIO#UART 1#UART 1#CAN 0#CAN 0#GPIO1 MIO#PCIE#UART 0#UART 0#CAN 1#CAN 1#GPIO1 MIO#GPIO1 MIO#USB0 Reset#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#MDIO 3#MDIO 3} CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#miso_mo1#mo2#mo3#mosi_mi0#n_ss_out#clk_for_lpbk#n_ss_out_upper#mo_upper[0]#mo_upper[1]#mo_upper[2]#mo_upper[3]#sclk_out_upper#sdio0_data_out[0]#sdio0_data_out[1]#sdio0_data_out[2]#sdio0_data_out[3]#sdio0_data_out[4]#sdio0_data_out[5]#sdio0_data_out[6]#sdio0_data_out[7]#sdio0_cmd_out#sdio0_clk_out#sdio0_bus_pow###gpio1[26]#dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in#gpio1[31]#txd#rxd#phy_rx#phy_tx#gpio1[36]#reset_n#rxd#txd#phy_tx#phy_rx#gpio1[42]#gpio1[43]#reset#sdio1_cd_n#sdio1_data_out[0]#sdio1_data_out[1]#sdio1_data_out[2]#sdio1_data_out[3]#sdio1_cmd_out#sdio1_clk_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem3_mdc#gem3_mdio_out} CONFIG.PSU_SD0_INTERNAL_BUS_WIDTH {8} CONFIG.PSU_SD1_INTERNAL_BUS_WIDTH {4} CONFIG.PSU_SMC_CYCLE_T0 {NA} CONFIG.PSU_SMC_CYCLE_T1 {NA} CONFIG.PSU_SMC_CYCLE_T2 {NA} CONFIG.PSU_SMC_CYCLE_T3 {NA} CONFIG.PSU_SMC_CYCLE_T4 {NA} CONFIG.PSU_SMC_CYCLE_T5 {NA} CONFIG.PSU_SMC_CYCLE_T6 {NA} CONFIG.PSU_USB3__DUAL_CLOCK_ENABLE {1} CONFIG.PSU_VALUE_SILVERSION {3} CONFIG.PSU__ACPU0__POWER__ON {1} CONFIG.PSU__ACPU1__POWER__ON {1} CONFIG.PSU__ACPU2__POWER__ON {1} CONFIG.PSU__ACPU3__POWER__ON {1} CONFIG.PSU__ACTUAL__IP {1} CONFIG.PSU__ACT_DDR_FREQ_MHZ {1200.000000} CONFIG.PSU__AUX_REF_CLK__FREQMHZ {33.333} CONFIG.PSU__CAN0_LOOP_CAN1__ENABLE {0} CONFIG.PSU__CAN0__GRP_CLK__ENABLE {0} CONFIG.PSU__CAN0__PERIPHERAL__ENABLE {1} CONFIG.PSU__CAN0__PERIPHERAL__IO {MIO 34 .. 35} CONFIG.PSU__CAN1__GRP_CLK__ENABLE {0} CONFIG.PSU__CAN1__PERIPHERAL__ENABLE {1} CONFIG.PSU__CAN1__PERIPHERAL__IO {MIO 40 .. 41} CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1333.333252} CONFIG.PSU__CRF_APB__ACPU_CTRL__FREQMHZ {1334} CONFIG.PSU__CRF_APB__ACPU_CTRL__SRCSEL {APLL} CONFIG.PSU__CRF_APB__ACPU__FRAC_ENABLED {0} CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__ACT_FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__DIVISOR0 {2} CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__AFI0_REF__ENABLE {0} CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__ACT_FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__DIVISOR0 {2} CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__AFI1_REF__ENABLE {0} CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__ACT_FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__DIVISOR0 {2} CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__AFI2_REF__ENABLE {0} CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__ACT_FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__DIVISOR0 {2} CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__AFI3_REF__ENABLE {0} CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__ACT_FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__DIVISOR0 {2} CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__AFI4_REF__ENABLE {0} CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__ACT_FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__DIVISOR0 {2} CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__FREQMHZ {667} CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__AFI5_REF__ENABLE {0} CONFIG.PSU__CRF_APB__APLL_CTRL__FRACFREQ {27.138} CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL {PSS_REF_CLK} CONFIG.PSU__CRF_APB__APM_CTRL__ACT_FREQMHZ {1} CONFIG.PSU__CRF_APB__APM_CTRL__DIVISOR0 {1} CONFIG.PSU__CRF_APB__APM_CTRL__FREQMHZ {1} CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {250.000000} CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__ACT_FREQMHZ {250} CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ {250} CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ {250.000000} CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ {250} CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {600.000000} CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1200} CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {600.000000} CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__DPLL_CTRL__FRACFREQ {27.138} CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ {25.000000} CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ {25} CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED {0} CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ {26.666666} CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ {27} CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ {300.000000} CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ {300} CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED {0} CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {600.000000} CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {DPLL} CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ {500.000000} CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {500} CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__ACT_FREQMHZ {-1} CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__DIVISOR0 {-1} CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__FREQMHZ {-1} CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__SRCSEL {NA} CONFIG.PSU__CRF_APB__GTGREF0__ENABLE {NA} CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__ACT_FREQMHZ {250.000000} CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__FREQMHZ {250} CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ {250} CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {444.444427} CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {APLL} CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACFREQ {27.138} CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {500.000000} CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {500} CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__ACT_FREQMHZ {500} CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__FREQMHZ {500} CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__AFI6__ENABLE {0} CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {50.000000} CONFIG.PSU__CRL_APB__AMS_REF_CTRL__FREQMHZ {50} CONFIG.PSU__CRL_APB__AMS_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {500.000000} CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {500} CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__ACT_FREQMHZ {180} CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__DIVISOR0 {3} CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__SRCSEL {SysOsc} CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {250.000000} CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ {250} CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__ACT_FREQMHZ {1000} CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__DIVISOR0 {6} CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__FREQMHZ {1000} CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ {1500.000000} CONFIG.PSU__CRL_APB__DLL_REF_CTRL__FREQMHZ {1500} CONFIG.PSU__CRL_APB__DLL_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__ACT_FREQMHZ {125.000000} CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ {125} CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ {125} CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ {125} CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__ACT_FREQMHZ {125} CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__FREQMHZ {125} CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {125.000000} CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ {125} CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {250.000000} CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ {250} CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__IOPLL_CTRL__FRACFREQ {27.138} CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL {PSS_REF_CLK} CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {250.000000} CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {250} CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {500.000000} CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {500} CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__NAND_REF_CTRL__ACT_FREQMHZ {100} CONFIG.PSU__CRL_APB__NAND_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__NAND_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__ACT_FREQMHZ {500} CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__DIVISOR0 {3} CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__FREQMHZ {500} CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {187.500000} CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {200.000000} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRL_APB__PL2_REF_CTRL__ACT_FREQMHZ {100} CONFIG.PSU__CRL_APB__PL3_REF_CTRL__ACT_FREQMHZ {100} CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {125.000000} CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACFREQ {27.138} CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ {187.500000} CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__FREQMHZ {200} CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {187.500000} CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__ACT_FREQMHZ {200.000000} CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__FREQMHZ {200} CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ {214} CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ {200} CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {100.000000} CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {250.000000} CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ {250} CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ {250} CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {20.000000} CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} CONFIG.PSU__CRL_APB__USB3__ENABLE {1} CONFIG.PSU__CSUPMU__PERIPHERAL__VALID {0} CONFIG.PSU__CSU__CSU_TAMPER_0__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_10__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_11__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_12__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_1__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_2__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_3__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_4__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_5__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_6__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_7__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_8__ENABLE {0} CONFIG.PSU__CSU__CSU_TAMPER_9__ENABLE {0} CONFIG.PSU__CSU__PERIPHERAL__ENABLE {0} CONFIG.PSU__DDRC__AL {0} CONFIG.PSU__DDRC__BG_ADDR_COUNT {1} CONFIG.PSU__DDRC__BRC_MAPPING {ROW_BANK_COL} CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} CONFIG.PSU__DDRC__CL {16} CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} CONFIG.PSU__DDRC__COMPONENTS {Components} CONFIG.PSU__DDRC__CWL {16} CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0} CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE {0} CONFIG.PSU__DDRC__DDR4_CRC_CONTROL {0} CONFIG.PSU__DDRC__DDR4_MAXPWR_SAVING_EN {0} CONFIG.PSU__DDRC__DDR4_T_REF_MODE {0} CONFIG.PSU__DDRC__DDR4_T_REF_RANGE {Normal (0-85)} CONFIG.PSU__DDRC__DEVICE_CAPACITY {16384 MBits} CONFIG.PSU__DDRC__DM_DBI {DM_NO_DBI} CONFIG.PSU__DDRC__DRAM_WIDTH {16 Bits} CONFIG.PSU__DDRC__ECC {Disabled} CONFIG.PSU__DDRC__ECC_SCRUB {0} CONFIG.PSU__DDRC__ENABLE {1} CONFIG.PSU__DDRC__ENABLE_2T_TIMING {0} CONFIG.PSU__DDRC__ENABLE_DP_SWITCH {0} CONFIG.PSU__DDRC__EN_2ND_CLK {0} CONFIG.PSU__DDRC__FGRM {1X} CONFIG.PSU__DDRC__FREQ_MHZ {1} CONFIG.PSU__DDRC__LPDDR3_DUALRANK_SDP {0} CONFIG.PSU__DDRC__LP_ASR {manual normal} CONFIG.PSU__DDRC__MEMORY_TYPE {DDR 4} CONFIG.PSU__DDRC__PARITY_ENABLE {0} CONFIG.PSU__DDRC__PER_BANK_REFRESH {0} CONFIG.PSU__DDRC__PHY_DBI_MODE {0} CONFIG.PSU__DDRC__PLL_BYPASS {0} CONFIG.PSU__DDRC__PWR_DOWN_EN {0} CONFIG.PSU__DDRC__RANK_ADDR_COUNT {0} CONFIG.PSU__DDRC__RD_DQS_CENTER {0} CONFIG.PSU__DDRC__ROW_ADDR_COUNT {17} CONFIG.PSU__DDRC__SELF_REF_ABORT {0} CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2400P} CONFIG.PSU__DDRC__STATIC_RD_MODE {0} CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} CONFIG.PSU__DDRC__T_FAW {30.0} CONFIG.PSU__DDRC__T_RAS_MIN {32} CONFIG.PSU__DDRC__T_RC {45.32} CONFIG.PSU__DDRC__T_RCD {16} CONFIG.PSU__DDRC__T_RP {16} CONFIG.PSU__DDRC__VIDEO_BUFFER_SIZE {0} CONFIG.PSU__DDRC__VREF {1} CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {1} CONFIG.PSU__DDR_QOS_ENABLE {0} CONFIG.PSU__DDR_SW_REFRESH_ENABLED {1} CONFIG.PSU__DDR__INTERFACE__FREQMHZ {600.000} CONFIG.PSU__DEVICE_TYPE {EG} CONFIG.PSU__DISPLAYPORT__LANE0__ENABLE {1} CONFIG.PSU__DISPLAYPORT__LANE0__IO {GT Lane3} CONFIG.PSU__DISPLAYPORT__LANE1__ENABLE {1} CONFIG.PSU__DISPLAYPORT__LANE1__IO {GT Lane2} CONFIG.PSU__DISPLAYPORT__PERIPHERAL__ENABLE {1} CONFIG.PSU__DLL__ISUSED {1} CONFIG.PSU__DPAUX__PERIPHERAL__ENABLE {1} CONFIG.PSU__DPAUX__PERIPHERAL__IO {MIO 27 .. 30} CONFIG.PSU__DP__LANE_SEL {Dual Higher} CONFIG.PSU__DP__REF_CLK_FREQ {27} CONFIG.PSU__DP__REF_CLK_SEL {Ref Clk2} CONFIG.PSU__ENABLE__DDR__REFRESH__SIGNALS {0} CONFIG.PSU__ENET0__FIFO__ENABLE {0} CONFIG.PSU__ENET0__GRP_MDIO__ENABLE {1} CONFIG.PSU__ENET0__GRP_MDIO__IO {EMIO} CONFIG.PSU__ENET0__PERIPHERAL__ENABLE {1} CONFIG.PSU__ENET0__PERIPHERAL__IO {EMIO} CONFIG.PSU__ENET0__PTP__ENABLE {0} CONFIG.PSU__ENET1__PERIPHERAL__ENABLE {0} CONFIG.PSU__ENET2__PERIPHERAL__ENABLE {0} CONFIG.PSU__ENET3__FIFO__ENABLE {0} CONFIG.PSU__ENET3__GRP_MDIO__ENABLE {1} CONFIG.PSU__ENET3__GRP_MDIO__IO {MIO 76 .. 77} CONFIG.PSU__ENET3__PERIPHERAL__ENABLE {1} CONFIG.PSU__ENET3__PERIPHERAL__IO {MIO 64 .. 75} CONFIG.PSU__ENET3__PTP__ENABLE {0} CONFIG.PSU__ENET3__TSU__ENABLE {0} CONFIG.PSU__EN_AXI_STATUS_PORTS {0} CONFIG.PSU__EN_EMIO_TRACE {0} CONFIG.PSU__EP__IP {0} CONFIG.PSU__EXPAND__CORESIGHT {0} CONFIG.PSU__EXPAND__FPD_SLAVES {0} CONFIG.PSU__EXPAND__GIC {0} CONFIG.PSU__EXPAND__LOWER_LPS_SLAVES {0} CONFIG.PSU__EXPAND__UPPER_LPS_SLAVES {0} CONFIG.PSU__FPDMASTERS_COHERENCY {0} CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {100.000000} CONFIG.PSU__FPGA_PL0_ENABLE {1} CONFIG.PSU__FPGA_PL1_ENABLE {1} CONFIG.PSU__FPGA_PL2_ENABLE {0} CONFIG.PSU__FPGA_PL3_ENABLE {0} CONFIG.PSU__FP__POWER__ON {1} CONFIG.PSU__FTM__CTI_IN_0 {0} CONFIG.PSU__FTM__CTI_IN_1 {0} CONFIG.PSU__FTM__CTI_IN_2 {0} CONFIG.PSU__FTM__CTI_IN_3 {0} CONFIG.PSU__FTM__CTI_OUT_0 {0} CONFIG.PSU__FTM__CTI_OUT_1 {0} CONFIG.PSU__FTM__CTI_OUT_2 {0} CONFIG.PSU__FTM__CTI_OUT_3 {0} CONFIG.PSU__FTM__GPI {0} CONFIG.PSU__FTM__GPO {0} CONFIG.PSU__GEM0_COHERENCY {0} CONFIG.PSU__GEM0_ROUTE_THROUGH_FPD {0} CONFIG.PSU__GEM3_COHERENCY {0} CONFIG.PSU__GEM3_ROUTE_THROUGH_FPD {0} CONFIG.PSU__GEM__TSU__ENABLE {0} CONFIG.PSU__GEN_IPI_0__MASTER {APU} CONFIG.PSU__GEN_IPI_10__MASTER {NONE} CONFIG.PSU__GEN_IPI_1__MASTER {RPU0} CONFIG.PSU__GEN_IPI_2__MASTER {RPU1} CONFIG.PSU__GEN_IPI_3__MASTER {PMU} CONFIG.PSU__GEN_IPI_4__MASTER {PMU} CONFIG.PSU__GEN_IPI_5__MASTER {PMU} CONFIG.PSU__GEN_IPI_6__MASTER {PMU} CONFIG.PSU__GEN_IPI_7__MASTER {NONE} CONFIG.PSU__GEN_IPI_8__MASTER {NONE} CONFIG.PSU__GEN_IPI_9__MASTER {NONE} CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE {0} CONFIG.PSU__GPIO1_MIO__IO {MIO 26 .. 51} CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE {1} CONFIG.PSU__GPIO2_MIO__PERIPHERAL__ENABLE {0} CONFIG.PSU__GPIO_EMIO_WIDTH {95} CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {1} CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {95} CONFIG.PSU__GPIO_EMIO__WIDTH {[94:0]} CONFIG.PSU__GPU_PP0__POWER__ON {1} CONFIG.PSU__GPU_PP1__POWER__ON {1} CONFIG.PSU__GT_REF_CLK__FREQMHZ {33.333} CONFIG.PSU__GT__LINK_SPEED {HBR} CONFIG.PSU__GT__PRE_EMPH_LVL_4 {0} CONFIG.PSU__GT__VLT_SWNG_LVL_4 {0} CONFIG.PSU__HPM0_FPD__NUM_READ_THREADS {4} CONFIG.PSU__HPM0_FPD__NUM_WRITE_THREADS {4} CONFIG.PSU__HPM0_LPD__NUM_READ_THREADS {4} CONFIG.PSU__HPM0_LPD__NUM_WRITE_THREADS {4} CONFIG.PSU__HPM1_FPD__NUM_READ_THREADS {4} CONFIG.PSU__HPM1_FPD__NUM_WRITE_THREADS {4} CONFIG.PSU__I2C0_LOOP_I2C1__ENABLE {0} CONFIG.PSU__I2C0__GRP_INT__ENABLE {0} CONFIG.PSU__I2C0__PERIPHERAL__ENABLE {1} CONFIG.PSU__I2C0__PERIPHERAL__IO {EMIO} CONFIG.PSU__I2C1__GRP_INT__ENABLE {0} CONFIG.PSU__I2C1__PERIPHERAL__ENABLE {1} CONFIG.PSU__I2C1__PERIPHERAL__IO {EMIO} CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC0_SEL {APB} CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC1_SEL {APB} CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC2_SEL {APB} CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC3_SEL {APB} CONFIG.PSU__IOU_SLCR__TTC0__ACT_FREQMHZ {100.000000} CONFIG.PSU__IOU_SLCR__TTC1__ACT_FREQMHZ {100.000000} CONFIG.PSU__IOU_SLCR__TTC2__ACT_FREQMHZ {100.000000} CONFIG.PSU__IOU_SLCR__TTC3__ACT_FREQMHZ {100.000000} CONFIG.PSU__IOU_SLCR__WDT0__ACT_FREQMHZ {100.000000} CONFIG.PSU__IRQ_P2F_ADMA_CHAN__INT {0} CONFIG.PSU__IRQ_P2F_AIB_AXI__INT {0} CONFIG.PSU__IRQ_P2F_AMS__INT {0} CONFIG.PSU__IRQ_P2F_APM_FPD__INT {0} CONFIG.PSU__IRQ_P2F_APU_COMM__INT {0} CONFIG.PSU__IRQ_P2F_APU_CPUMNT__INT {0} CONFIG.PSU__IRQ_P2F_APU_CTI__INT {0} CONFIG.PSU__IRQ_P2F_APU_EXTERR__INT {0} CONFIG.PSU__IRQ_P2F_APU_IPI__INT {0} CONFIG.PSU__IRQ_P2F_APU_L2ERR__INT {0} CONFIG.PSU__IRQ_P2F_APU_PMU__INT {0} CONFIG.PSU__IRQ_P2F_APU_REGS__INT {0} CONFIG.PSU__IRQ_P2F_ATB_LPD__INT {0} CONFIG.PSU__IRQ_P2F_CAN0__INT {0} CONFIG.PSU__IRQ_P2F_CAN1__INT {0} CONFIG.PSU__IRQ_P2F_CLKMON__INT {0} CONFIG.PSU__IRQ_P2F_DDR_SS__INT {0} CONFIG.PSU__IRQ_P2F_DPDMA__INT {0} CONFIG.PSU__IRQ_P2F_DPORT__INT {0} CONFIG.PSU__IRQ_P2F_EFUSE__INT {0} CONFIG.PSU__IRQ_P2F_ENT0_WAKEUP__INT {0} CONFIG.PSU__IRQ_P2F_ENT0__INT {0} CONFIG.PSU__IRQ_P2F_ENT3_WAKEUP__INT {0} CONFIG.PSU__IRQ_P2F_ENT3__INT {0} CONFIG.PSU__IRQ_P2F_FPD_APB__INT {0} CONFIG.PSU__IRQ_P2F_FPD_ATB_ERR__INT {0} CONFIG.PSU__IRQ_P2F_FP_WDT__INT {0} CONFIG.PSU__IRQ_P2F_GDMA_CHAN__INT {0} CONFIG.PSU__IRQ_P2F_GPIO__INT {0} CONFIG.PSU__IRQ_P2F_GPU__INT {0} CONFIG.PSU__IRQ_P2F_I2C0__INT {0} CONFIG.PSU__IRQ_P2F_I2C1__INT {0} CONFIG.PSU__IRQ_P2F_LPD_APB__INT {0} CONFIG.PSU__IRQ_P2F_LPD_APM__INT {0} CONFIG.PSU__IRQ_P2F_LP_WDT__INT {0} CONFIG.PSU__IRQ_P2F_OCM_ERR__INT {0} CONFIG.PSU__IRQ_P2F_PCIE_DMA__INT {0} CONFIG.PSU__IRQ_P2F_PCIE_LEGACY__INT {0} CONFIG.PSU__IRQ_P2F_PCIE_MSC__INT {0} CONFIG.PSU__IRQ_P2F_PCIE_MSI__INT {0} CONFIG.PSU__IRQ_P2F_PL_IPI__INT {0} CONFIG.PSU__IRQ_P2F_QSPI__INT {0} CONFIG.PSU__IRQ_P2F_R5_CORE0_ECC_ERR__INT {0} CONFIG.PSU__IRQ_P2F_R5_CORE1_ECC_ERR__INT {0} CONFIG.PSU__IRQ_P2F_RPU_IPI__INT {0} CONFIG.PSU__IRQ_P2F_RPU_PERMON__INT {0} CONFIG.PSU__IRQ_P2F_RTC_ALARM__INT {0} CONFIG.PSU__IRQ_P2F_RTC_SECONDS__INT {0} CONFIG.PSU__IRQ_P2F_SATA__INT {0} CONFIG.PSU__IRQ_P2F_SDIO0_WAKE__INT {0} CONFIG.PSU__IRQ_P2F_SDIO0__INT {0} CONFIG.PSU__IRQ_P2F_SDIO1_WAKE__INT {0} CONFIG.PSU__IRQ_P2F_SDIO1__INT {0} CONFIG.PSU__IRQ_P2F_TTC0__INT0 {0} CONFIG.PSU__IRQ_P2F_TTC0__INT1 {0} CONFIG.PSU__IRQ_P2F_TTC0__INT2 {0} CONFIG.PSU__IRQ_P2F_TTC1__INT0 {0} CONFIG.PSU__IRQ_P2F_TTC1__INT1 {0} CONFIG.PSU__IRQ_P2F_TTC1__INT2 {0} CONFIG.PSU__IRQ_P2F_TTC2__INT0 {0} CONFIG.PSU__IRQ_P2F_TTC2__INT1 {0} CONFIG.PSU__IRQ_P2F_TTC2__INT2 {0} CONFIG.PSU__IRQ_P2F_TTC3__INT0 {0} CONFIG.PSU__IRQ_P2F_TTC3__INT1 {0} CONFIG.PSU__IRQ_P2F_TTC3__INT2 {0} CONFIG.PSU__IRQ_P2F_UART0__INT {0} CONFIG.PSU__IRQ_P2F_UART1__INT {0} CONFIG.PSU__IRQ_P2F_USB3_ENDPOINT__INT0 {0} CONFIG.PSU__IRQ_P2F_USB3_ENDPOINT__INT1 {0} CONFIG.PSU__IRQ_P2F_USB3_OTG__INT0 {0} CONFIG.PSU__IRQ_P2F_USB3_OTG__INT1 {0} CONFIG.PSU__IRQ_P2F_USB3_PMU_WAKEUP__INT {0} CONFIG.PSU__IRQ_P2F_XMPU_FPD__INT {0} CONFIG.PSU__IRQ_P2F_XMPU_LPD__INT {0} CONFIG.PSU__IRQ_P2F__INTF_FPD_SMMU__INT {0} CONFIG.PSU__IRQ_P2F__INTF_PPD_CCI__INT {0} CONFIG.PSU__L2_BANK0__POWER__ON {1} CONFIG.PSU__LPDMA0_COHERENCY {0} CONFIG.PSU__LPDMA1_COHERENCY {0} CONFIG.PSU__LPDMA2_COHERENCY {0} CONFIG.PSU__LPDMA3_COHERENCY {0} CONFIG.PSU__LPDMA4_COHERENCY {0} CONFIG.PSU__LPDMA5_COHERENCY {0} CONFIG.PSU__LPDMA6_COHERENCY {0} CONFIG.PSU__LPDMA7_COHERENCY {0} CONFIG.PSU__LPD_SLCR__CSUPMU_WDT_CLK_SEL__SELECT {APB} CONFIG.PSU__LPD_SLCR__CSUPMU__ACT_FREQMHZ {100} CONFIG.PSU__LPD_SLCR__CSUPMU__FREQMHZ {100} CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} CONFIG.PSU__M_AXI_GP0_SUPPORTS_NARROW_BURST {1} CONFIG.PSU__M_AXI_GP1_SUPPORTS_NARROW_BURST {1} CONFIG.PSU__M_AXI_GP2_SUPPORTS_NARROW_BURST {1} CONFIG.PSU__NAND__PERIPHERAL__ENABLE {0} CONFIG.PSU__NAND__READY_BUSY__ENABLE {0} CONFIG.PSU__NUM_FABRIC_RESETS {1} CONFIG.PSU__OCM_BANK0__POWER__ON {1} CONFIG.PSU__OCM_BANK1__POWER__ON {1} CONFIG.PSU__OCM_BANK2__POWER__ON {1} CONFIG.PSU__OCM_BANK3__POWER__ON {1} CONFIG.PSU__OVERRIDE_HPX_QOS {0} CONFIG.PSU__OVERRIDE__BASIC_CLOCK {0} CONFIG.PSU__PCIE__ACS_VIOLAION {0} CONFIG.PSU__PCIE__AER_CAPABILITY {0} CONFIG.PSU__PCIE__BAR0_64BIT {0} CONFIG.PSU__PCIE__BAR0_ENABLE {1} CONFIG.PSU__PCIE__BAR0_PREFETCHABLE {0} CONFIG.PSU__PCIE__BAR0_SCALE {Megabytes} CONFIG.PSU__PCIE__BAR0_SIZE {1} CONFIG.PSU__PCIE__BAR0_TYPE {Memory} CONFIG.PSU__PCIE__BAR0_VAL {0xfff00000} CONFIG.PSU__PCIE__BAR1_ENABLE {0} CONFIG.PSU__PCIE__BAR1_VAL {0x0} CONFIG.PSU__PCIE__BAR2_VAL {0x0} CONFIG.PSU__PCIE__BAR3_VAL {0x0} CONFIG.PSU__PCIE__BAR4_VAL {0x0} CONFIG.PSU__PCIE__BAR5_VAL {0x0} CONFIG.PSU__PCIE__CLASS_CODE_BASE {0x06} CONFIG.PSU__PCIE__CLASS_CODE_INTERFACE {0x0} CONFIG.PSU__PCIE__CLASS_CODE_SUB {0x04} CONFIG.PSU__PCIE__CLASS_CODE_VALUE {0x60400} CONFIG.PSU__PCIE__CRS_SW_VISIBILITY {0} CONFIG.PSU__PCIE__DEVICE_ID {0xD011} CONFIG.PSU__PCIE__DEVICE_PORT_TYPE {Root Port} CONFIG.PSU__PCIE__EROM_ENABLE {0} CONFIG.PSU__PCIE__EROM_VAL {0x0} CONFIG.PSU__PCIE__INTX_GENERATION {1} CONFIG.PSU__PCIE__LANE0__ENABLE {1} CONFIG.PSU__PCIE__LANE0__IO {GT Lane0} CONFIG.PSU__PCIE__LANE1__ENABLE {0} CONFIG.PSU__PCIE__LANE2__ENABLE {0} CONFIG.PSU__PCIE__LANE3__ENABLE {0} CONFIG.PSU__PCIE__LINK_SPEED {5.0 Gb/s} CONFIG.PSU__PCIE__MAXIMUM_LINK_WIDTH {x1} CONFIG.PSU__PCIE__MAX_PAYLOAD_SIZE {256 bytes} CONFIG.PSU__PCIE__PERIPHERAL__ENABLE {1} CONFIG.PSU__PCIE__PERIPHERAL__ENDPOINT_ENABLE {0} CONFIG.PSU__PCIE__PERIPHERAL__ROOTPORT_ENABLE {1} CONFIG.PSU__PCIE__PERIPHERAL__ROOTPORT_IO {MIO 37} CONFIG.PSU__PCIE__REF_CLK_FREQ {100} CONFIG.PSU__PCIE__REF_CLK_SEL {Ref Clk0} CONFIG.PSU__PCIE__RESET__POLARITY {Active Low} CONFIG.PSU__PCIE__REVISION_ID {0x0} CONFIG.PSU__PCIE__SUBSYSTEM_ID {0x7} CONFIG.PSU__PCIE__SUBSYSTEM_VENDOR_ID {0x10EE} CONFIG.PSU__PCIE__VENDOR_ID {0x10EE} CONFIG.PSU__PJTAG__PERIPHERAL__ENABLE {0} CONFIG.PSU__PL_CLK0_BUF {TRUE} CONFIG.PSU__PL_CLK1_BUF {TRUE} CONFIG.PSU__PL__POWER__ON {1} CONFIG.PSU__PMU__PERIPHERAL__ENABLE {0} CONFIG.PSU__PRESET_APPLIED {1} CONFIG.PSU__PROTECTION__DDR_SEGMENTS {NONE} CONFIG.PSU__PROTECTION__ENABLE {0} CONFIG.PSU__PROTECTION__FPD_SEGMENTS {SA:0xFD1A0000 ;SIZE:1280;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD000000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD010000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD020000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD030000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD040000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD050000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD610000 ;SIZE:512;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware          |          SA:0xFD5D0000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware} CONFIG.PSU__PROTECTION__LPD_SEGMENTS {SA:0xFF980000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFF5E0000 ;SIZE:2560;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFFCC0000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFF180000 ;SIZE:768;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFF410000 ;SIZE:640;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFFA70000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware|SA:0xFF9A0000 ;SIZE:64;UNIT:KB ;RegionTZ:Secure ;WrAllowed:Read/Write;subsystemId:PMU Firmware} CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;1|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;1|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;1|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} CONFIG.PSU__PROTECTION__MASTERS_TZ {GEM0:NonSecure|SD1:NonSecure|GEM2:NonSecure|GEM1:NonSecure|GEM3:NonSecure|PCIe:NonSecure|DP:NonSecure|NAND:NonSecure|GPU:NonSecure|USB1:NonSecure|USB0:NonSecure|LDMA:NonSecure|FDMA:NonSecure|QSPI:NonSecure|SD0:NonSecure} CONFIG.PSU__PROTECTION__OCM_SEGMENTS {NONE} CONFIG.PSU__PROTECTION__PRESUBSYSTEMS {NONE} CONFIG.PSU__PROTECTION__SLAVES {LPD;USB3_1_XHCI;FE300000;FE3FFFFF;0|LPD;USB3_1;FF9E0000;FF9EFFFF;0|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;1|LPD;UART0;FF000000;FF00FFFF;1|LPD;TTC3;FF140000;FF14FFFF;1|LPD;TTC2;FF130000;FF13FFFF;1|LPD;TTC1;FF120000;FF12FFFF;1|LPD;TTC0;FF110000;FF11FFFF;1|FPD;SWDT1;FD4D0000;FD4DFFFF;1|LPD;SWDT0;FF150000;FF15FFFF;1|LPD;SPI1;FF050000;FF05FFFF;0|LPD;SPI0;FF040000;FF04FFFF;0|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;1|LPD;SD0;FF160000;FF16FFFF;1|FPD;SATA;FD0C0000;FD0CFFFF;0|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;1|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;1|FPD;PCIE_LOW;E0000000;EFFFFFFF;1|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;1|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;1|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;1|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;1|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;1|FPD;GPU;FD4B0000;FD4BFFFF;1|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;1|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;0|LPD;GEM0;FF0B0000;FF0BFFFF;1|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display Port;FD4A0000;FD4AFFFF;1|FPD;DPDMA;FD4C0000;FD4CFFFF;1|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;97FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;1|LPD;CAN0;FF060000;FF06FFFF;1|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1} CONFIG.PSU__PROTECTION__SUBSYSTEMS {PMU Firmware:PMU} CONFIG.PSU__PSS_ALT_REF_CLK__ENABLE {0} CONFIG.PSU__PSS_ALT_REF_CLK__FREQMHZ {33.333} CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.333333} CONFIG.PSU__QSPI_COHERENCY {0} CONFIG.PSU__QSPI_ROUTE_THROUGH_FPD {0} CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE {1} CONFIG.PSU__QSPI__GRP_FBCLK__IO {MIO 6} CONFIG.PSU__QSPI__PERIPHERAL__DATA_MODE {x4} CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {1} CONFIG.PSU__QSPI__PERIPHERAL__IO {MIO 0 .. 12} CONFIG.PSU__QSPI__PERIPHERAL__MODE {Dual Parallel} CONFIG.PSU__REPORT__DBGLOG {0} CONFIG.PSU__RPU_COHERENCY {0} CONFIG.PSU__RPU__POWER__ON {1} CONFIG.PSU__SATA__PERIPHERAL__ENABLE {0} CONFIG.PSU__SAXIGP3__DATA_WIDTH {128} CONFIG.PSU__SD0_COHERENCY {0} CONFIG.PSU__SD0_ROUTE_THROUGH_FPD {0} CONFIG.PSU__SD0__DATA_TRANSFER_MODE {8Bit} CONFIG.PSU__SD0__GRP_POW__ENABLE {1} CONFIG.PSU__SD0__GRP_POW__IO {MIO 23} CONFIG.PSU__SD0__PERIPHERAL__ENABLE {1} CONFIG.PSU__SD0__PERIPHERAL__IO {MIO 13 .. 22} CONFIG.PSU__SD0__RESET__ENABLE {1} CONFIG.PSU__SD0__SLOT_TYPE {eMMC} CONFIG.PSU__SD1_COHERENCY {0} CONFIG.PSU__SD1_ROUTE_THROUGH_FPD {0} CONFIG.PSU__SD1__DATA_TRANSFER_MODE {4Bit} CONFIG.PSU__SD1__GRP_CD__ENABLE {1} CONFIG.PSU__SD1__GRP_CD__IO {MIO 45} CONFIG.PSU__SD1__GRP_POW__ENABLE {0} CONFIG.PSU__SD1__GRP_WP__ENABLE {0} CONFIG.PSU__SD1__PERIPHERAL__ENABLE {1} CONFIG.PSU__SD1__PERIPHERAL__IO {MIO 46 .. 51} CONFIG.PSU__SD1__SLOT_TYPE {SD 2.0} CONFIG.PSU__SPI0_LOOP_SPI1__ENABLE {0} CONFIG.PSU__SPI0__PERIPHERAL__ENABLE {0} CONFIG.PSU__SPI1__PERIPHERAL__ENABLE {0} CONFIG.PSU__SWDT0__CLOCK__ENABLE {0} CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE {1} CONFIG.PSU__SWDT0__PERIPHERAL__IO {NA} CONFIG.PSU__SWDT0__RESET__ENABLE {0} CONFIG.PSU__SWDT1__CLOCK__ENABLE {0} CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE {1} CONFIG.PSU__SWDT1__PERIPHERAL__IO {NA} CONFIG.PSU__SWDT1__RESET__ENABLE {0} CONFIG.PSU__TCM0A__POWER__ON {1} CONFIG.PSU__TCM0B__POWER__ON {1} CONFIG.PSU__TCM1A__POWER__ON {1} CONFIG.PSU__TCM1B__POWER__ON {1} CONFIG.PSU__TESTSCAN__PERIPHERAL__ENABLE {0} CONFIG.PSU__TRACE__INTERNAL_WIDTH {32} CONFIG.PSU__TRACE__PERIPHERAL__ENABLE {0} CONFIG.PSU__TRISTATE__INVERTED {1} CONFIG.PSU__TSU__BUFG_PORT_PAIR {0} CONFIG.PSU__TTC0__CLOCK__ENABLE {0} CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1} CONFIG.PSU__TTC0__PERIPHERAL__IO {NA} CONFIG.PSU__TTC0__WAVEOUT__ENABLE {0} CONFIG.PSU__TTC1__CLOCK__ENABLE {0} CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {1} CONFIG.PSU__TTC1__PERIPHERAL__IO {NA} CONFIG.PSU__TTC1__WAVEOUT__ENABLE {0} CONFIG.PSU__TTC2__CLOCK__ENABLE {0} CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {1} CONFIG.PSU__TTC2__PERIPHERAL__IO {NA} CONFIG.PSU__TTC2__WAVEOUT__ENABLE {0} CONFIG.PSU__TTC3__CLOCK__ENABLE {0} CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {1} CONFIG.PSU__TTC3__PERIPHERAL__IO {NA} CONFIG.PSU__TTC3__WAVEOUT__ENABLE {0} CONFIG.PSU__UART0_LOOP_UART1__ENABLE {0} CONFIG.PSU__UART0__BAUD_RATE {115200} CONFIG.PSU__UART0__MODEM__ENABLE {0} CONFIG.PSU__UART0__PERIPHERAL__ENABLE {1} CONFIG.PSU__UART0__PERIPHERAL__IO {MIO 38 .. 39} CONFIG.PSU__UART1__BAUD_RATE {115200} CONFIG.PSU__UART1__MODEM__ENABLE {0} CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 32 .. 33} CONFIG.PSU__USB0_COHERENCY {0} CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} CONFIG.PSU__USB0__REF_CLK_FREQ {26} CONFIG.PSU__USB0__REF_CLK_SEL {Ref Clk1} CONFIG.PSU__USB0__RESET__ENABLE {1} CONFIG.PSU__USB0__RESET__IO {MIO 44} CONFIG.PSU__USB1__PERIPHERAL__ENABLE {0} CONFIG.PSU__USB1__RESET__ENABLE {0} CONFIG.PSU__USB2_0__EMIO__ENABLE {0} CONFIG.PSU__USB3_0__EMIO__ENABLE {0} CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {1} CONFIG.PSU__USB3_0__PERIPHERAL__IO {GT Lane1} CONFIG.PSU__USB__RESET__MODE {Separate MIO Pin} CONFIG.PSU__USB__RESET__POLARITY {Active Low} CONFIG.PSU__USE_DIFF_RW_CLK_GP3 {0} CONFIG.PSU__USE__ADMA {0} CONFIG.PSU__USE__APU_LEGACY_INTERRUPT {0} CONFIG.PSU__USE__AUDIO {0} CONFIG.PSU__USE__CLK {0} CONFIG.PSU__USE__CLK0 {0} CONFIG.PSU__USE__CLK1 {0} CONFIG.PSU__USE__CLK2 {0} CONFIG.PSU__USE__CLK3 {0} CONFIG.PSU__USE__CROSS_TRIGGER {0} CONFIG.PSU__USE__DDR_INTF_REQUESTED {0} CONFIG.PSU__USE__DEBUG__TEST {0} CONFIG.PSU__USE__EVENT_RPU {0} CONFIG.PSU__USE__FABRIC__RST {1} CONFIG.PSU__USE__FTM {0} CONFIG.PSU__USE__GDMA {0} CONFIG.PSU__USE__IRQ {0} CONFIG.PSU__USE__IRQ0 {1} CONFIG.PSU__USE__IRQ1 {1} CONFIG.PSU__USE__M_AXI_GP0 {1} CONFIG.PSU__USE__M_AXI_GP1 {0} CONFIG.PSU__USE__M_AXI_GP2 {0} CONFIG.PSU__USE__PROC_EVENT_BUS {0} CONFIG.PSU__USE__RPU_LEGACY_INTERRUPT {0} CONFIG.PSU__USE__RST0 {0} CONFIG.PSU__USE__RST1 {0} CONFIG.PSU__USE__RST2 {0} CONFIG.PSU__USE__RST3 {0} CONFIG.PSU__USE__RTC {0} CONFIG.PSU__USE__STM {0} CONFIG.PSU__USE__S_AXI_ACE {0} CONFIG.PSU__USE__S_AXI_ACP {0} CONFIG.PSU__USE__S_AXI_GP0 {0} CONFIG.PSU__USE__S_AXI_GP1 {0} CONFIG.PSU__USE__S_AXI_GP2 {0} CONFIG.PSU__USE__S_AXI_GP3 {1} CONFIG.PSU__USE__S_AXI_GP4 {0} CONFIG.PSU__USE__S_AXI_GP5 {0} CONFIG.PSU__USE__S_AXI_GP6 {0} CONFIG.PSU__USE__USB3_0_HUB {0} CONFIG.PSU__USE__USB3_1_HUB {0} CONFIG.PSU__USE__VIDEO {0} CONFIG.PSU__VIDEO_REF_CLK__ENABLE {0} CONFIG.PSU__VIDEO_REF_CLK__FREQMHZ {33.333} CONFIG.QSPI_BOARD_INTERFACE {custom} CONFIG.SATA_BOARD_INTERFACE {custom} CONFIG.SD0_BOARD_INTERFACE {custom} CONFIG.SD1_BOARD_INTERFACE {custom} CONFIG.SPI0_BOARD_INTERFACE {custom} CONFIG.SPI1_BOARD_INTERFACE {custom} CONFIG.SUBPRESET1 {Custom} CONFIG.SUBPRESET2 {Custom} CONFIG.SWDT0_BOARD_INTERFACE {custom} CONFIG.SWDT1_BOARD_INTERFACE {custom} CONFIG.TRACE_BOARD_INTERFACE {custom} CONFIG.TTC0_BOARD_INTERFACE {custom} CONFIG.TTC1_BOARD_INTERFACE {custom} CONFIG.TTC2_BOARD_INTERFACE {custom} CONFIG.TTC3_BOARD_INTERFACE {custom} CONFIG.UART0_BOARD_INTERFACE {custom} CONFIG.UART1_BOARD_INTERFACE {custom} CONFIG.USB0_BOARD_INTERFACE {custom} CONFIG.USB1_BOARD_INTERFACE {custom}] $cell} reason]} {
puts $audit "SET_FAILED	zynq_ultra_ps_e_0	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	zynq_ultra_ps_e_0	1012 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:xlconcat:2.1} xlconcat_3
set cell [get_bd_cells xlconcat_3]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.NUM_PORTS] < 0} {incr unsupported; puts $audit "MISSING	xlconcat_3	NUM_PORTS	6"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.NUM_PORTS {6}] $cell} reason]} {
puts $audit "SET_FAILED	xlconcat_3	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	xlconcat_3	1 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:smartconnect:1.0} smartconnect_0
set cell [get_bd_cells smartconnect_0]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.NUM_MI] < 0} {incr unsupported; puts $audit "MISSING	smartconnect_0	NUM_MI	1"}
if {[lsearch -exact $props CONFIG.NUM_SI] < 0} {incr unsupported; puts $audit "MISSING	smartconnect_0	NUM_SI	4"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.NUM_MI {1} CONFIG.NUM_SI {4}] $cell} reason]} {
puts $audit "SET_FAILED	smartconnect_0	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	smartconnect_0	2 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:system_ila:1.1} system_ila_0
set cell [get_bd_cells system_ila_0]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.C_MON_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_MON_TYPE	NATIVE"}
if {[lsearch -exact $props CONFIG.C_NUM_OF_PROBES] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_NUM_OF_PROBES	12"}
if {[lsearch -exact $props CONFIG.C_PROBE0_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE0_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE10_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE10_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE11_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE11_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE12_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE12_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE13_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE13_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE14_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE14_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE1_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE1_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE2_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE2_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE3_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE3_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE4_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE4_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE5_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE5_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE6_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE6_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE7_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE7_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE8_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE8_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE9_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_0	C_PROBE9_TYPE	0"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.C_MON_TYPE {NATIVE} CONFIG.C_NUM_OF_PROBES {12} CONFIG.C_PROBE0_TYPE {0} CONFIG.C_PROBE10_TYPE {0} CONFIG.C_PROBE11_TYPE {0} CONFIG.C_PROBE12_TYPE {0} CONFIG.C_PROBE13_TYPE {0} CONFIG.C_PROBE14_TYPE {0} CONFIG.C_PROBE1_TYPE {0} CONFIG.C_PROBE2_TYPE {0} CONFIG.C_PROBE3_TYPE {0} CONFIG.C_PROBE4_TYPE {0} CONFIG.C_PROBE5_TYPE {0} CONFIG.C_PROBE6_TYPE {0} CONFIG.C_PROBE7_TYPE {0} CONFIG.C_PROBE8_TYPE {0} CONFIG.C_PROBE9_TYPE {0}] $cell} reason]} {
puts $audit "SET_FAILED	system_ila_0	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	system_ila_0	17 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:system_ila:1.1} system_ila_1
set cell [get_bd_cells system_ila_1]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.C_MON_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_MON_TYPE	NATIVE"}
if {[lsearch -exact $props CONFIG.C_NUM_OF_PROBES] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_NUM_OF_PROBES	5"}
if {[lsearch -exact $props CONFIG.C_PROBE0_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE0_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE10_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE10_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE11_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE11_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE12_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE12_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE13_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE13_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE14_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE14_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE1_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE1_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE2_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE2_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE3_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE3_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE4_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE4_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE5_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE5_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE6_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE6_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE7_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE7_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE8_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE8_TYPE	0"}
if {[lsearch -exact $props CONFIG.C_PROBE9_TYPE] < 0} {incr unsupported; puts $audit "MISSING	system_ila_1	C_PROBE9_TYPE	0"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.C_MON_TYPE {NATIVE} CONFIG.C_NUM_OF_PROBES {5} CONFIG.C_PROBE0_TYPE {0} CONFIG.C_PROBE10_TYPE {0} CONFIG.C_PROBE11_TYPE {0} CONFIG.C_PROBE12_TYPE {0} CONFIG.C_PROBE13_TYPE {0} CONFIG.C_PROBE14_TYPE {0} CONFIG.C_PROBE1_TYPE {0} CONFIG.C_PROBE2_TYPE {0} CONFIG.C_PROBE3_TYPE {0} CONFIG.C_PROBE4_TYPE {0} CONFIG.C_PROBE5_TYPE {0} CONFIG.C_PROBE6_TYPE {0} CONFIG.C_PROBE7_TYPE {0} CONFIG.C_PROBE8_TYPE {0} CONFIG.C_PROBE9_TYPE {0}] $cell} reason]} {
puts $audit "SET_FAILED	system_ila_1	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	system_ila_1	17 original parameters"}}
create_bd_cell -type ip -vlnv {digilentinc.com:user:AXI_BayerToRGB:1.3} AXI_BayerToRGB_0
set cell [get_bd_cells AXI_BayerToRGB_0]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {digilentinc.com:user:AXI_BayerToRGB:1.3} AXI_BayerToRGB_1
set cell [get_bd_cells AXI_BayerToRGB_1]
set props [list_property $cell]
create_bd_cell -type module -reference axis_pixel_counter axis_pixel_counter_0
set cell [get_bd_cells axis_pixel_counter_0]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {alinx.com.cn:user:csi_4lane_raw10:2.0} csi_4lane_raw10_2
set cell [get_bd_cells csi_4lane_raw10_2]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.series] < 0} {incr unsupported; puts $audit "MISSING	csi_4lane_raw10_2	series	ULTRASCALE_PLUS"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.series {ULTRASCALE_PLUS}] $cell} reason]} {
puts $audit "SET_FAILED	csi_4lane_raw10_2	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	csi_4lane_raw10_2	1 original parameters"}}
create_bd_cell -type ip -vlnv {alinx.com.cn:user:csi_4lane_raw10:2.0} csi_4lane_raw10_3
set cell [get_bd_cells csi_4lane_raw10_3]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.series] < 0} {incr unsupported; puts $audit "MISSING	csi_4lane_raw10_3	series	ULTRASCALE_PLUS"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.series {ULTRASCALE_PLUS}] $cell} reason]} {
puts $audit "SET_FAILED	csi_4lane_raw10_3	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	csi_4lane_raw10_3	1 original parameters"}}
create_bd_cell -type ip -vlnv {digilentinc.com:user:AXI_BayerToRGB:1.3} AXI_BayerToRGB_2
set cell [get_bd_cells AXI_BayerToRGB_2]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {digilentinc.com:user:AXI_BayerToRGB:1.3} AXI_BayerToRGB_3
set cell [get_bd_cells AXI_BayerToRGB_3]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {digilentinc.com:user:AXI_GammaCorrection:1.0} AXI_GammaCorrection_2
set cell [get_bd_cells AXI_GammaCorrection_2]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {digilentinc.com:user:AXI_GammaCorrection:1.0} AXI_GammaCorrection_3
set cell [get_bd_cells AXI_GammaCorrection_3]
set props [list_property $cell]
create_bd_cell -type ip -vlnv {xilinx.com:ip:axis_subset_converter:1.1} axis_subset_converter_2
set cell [get_bd_cells axis_subset_converter_2]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.M_HAS_TKEEP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	M_HAS_TKEEP	1"}
if {[lsearch -exact $props CONFIG.M_HAS_TLAST] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	M_HAS_TLAST	1"}
if {[lsearch -exact $props CONFIG.M_TDATA_NUM_BYTES] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	M_TDATA_NUM_BYTES	3"}
if {[lsearch -exact $props CONFIG.M_TUSER_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	M_TUSER_WIDTH	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TKEEP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	S_HAS_TKEEP	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TLAST] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	S_HAS_TLAST	1"}
if {[lsearch -exact $props CONFIG.S_TDATA_NUM_BYTES] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	S_TDATA_NUM_BYTES	3"}
if {[lsearch -exact $props CONFIG.S_TUSER_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	S_TUSER_WIDTH	1"}
if {[lsearch -exact $props CONFIG.TDATA_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	TDATA_REMAP	tdata[23:16],tdata[7:0],tdata[15:8]"}
if {[lsearch -exact $props CONFIG.TDEST_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	TDEST_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TID_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	TID_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TKEEP_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	TKEEP_REMAP	tkeep[2:0]"}
if {[lsearch -exact $props CONFIG.TLAST_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	TLAST_REMAP	tlast[0]"}
if {[lsearch -exact $props CONFIG.TSTRB_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	TSTRB_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TUSER_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_2	TUSER_REMAP	tuser[0:0]"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.M_HAS_TKEEP {1} CONFIG.M_HAS_TLAST {1} CONFIG.M_TDATA_NUM_BYTES {3} CONFIG.M_TUSER_WIDTH {1} CONFIG.S_HAS_TKEEP {1} CONFIG.S_HAS_TLAST {1} CONFIG.S_TDATA_NUM_BYTES {3} CONFIG.S_TUSER_WIDTH {1} CONFIG.TDATA_REMAP {tdata[23:16],tdata[7:0],tdata[15:8]} CONFIG.TDEST_REMAP {1'b0} CONFIG.TID_REMAP {1'b0} CONFIG.TKEEP_REMAP {tkeep[2:0]} CONFIG.TLAST_REMAP {tlast[0]} CONFIG.TSTRB_REMAP {1'b0} CONFIG.TUSER_REMAP {tuser[0:0]}] $cell} reason]} {
puts $audit "SET_FAILED	axis_subset_converter_2	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axis_subset_converter_2	15 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axis_subset_converter:1.1} axis_subset_converter_3
set cell [get_bd_cells axis_subset_converter_3]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.M_HAS_TKEEP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	M_HAS_TKEEP	1"}
if {[lsearch -exact $props CONFIG.M_HAS_TLAST] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	M_HAS_TLAST	1"}
if {[lsearch -exact $props CONFIG.M_TDATA_NUM_BYTES] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	M_TDATA_NUM_BYTES	3"}
if {[lsearch -exact $props CONFIG.M_TUSER_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	M_TUSER_WIDTH	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TKEEP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	S_HAS_TKEEP	1"}
if {[lsearch -exact $props CONFIG.S_HAS_TLAST] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	S_HAS_TLAST	1"}
if {[lsearch -exact $props CONFIG.S_TDATA_NUM_BYTES] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	S_TDATA_NUM_BYTES	3"}
if {[lsearch -exact $props CONFIG.S_TUSER_WIDTH] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	S_TUSER_WIDTH	1"}
if {[lsearch -exact $props CONFIG.TDATA_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	TDATA_REMAP	tdata[23:16],tdata[7:0],tdata[15:8]"}
if {[lsearch -exact $props CONFIG.TDEST_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	TDEST_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TID_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	TID_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TKEEP_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	TKEEP_REMAP	tkeep[2:0]"}
if {[lsearch -exact $props CONFIG.TLAST_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	TLAST_REMAP	tlast[0]"}
if {[lsearch -exact $props CONFIG.TSTRB_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	TSTRB_REMAP	1'b0"}
if {[lsearch -exact $props CONFIG.TUSER_REMAP] < 0} {incr unsupported; puts $audit "MISSING	axis_subset_converter_3	TUSER_REMAP	tuser[0:0]"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.M_HAS_TKEEP {1} CONFIG.M_HAS_TLAST {1} CONFIG.M_TDATA_NUM_BYTES {3} CONFIG.M_TUSER_WIDTH {1} CONFIG.S_HAS_TKEEP {1} CONFIG.S_HAS_TLAST {1} CONFIG.S_TDATA_NUM_BYTES {3} CONFIG.S_TUSER_WIDTH {1} CONFIG.TDATA_REMAP {tdata[23:16],tdata[7:0],tdata[15:8]} CONFIG.TDEST_REMAP {1'b0} CONFIG.TID_REMAP {1'b0} CONFIG.TKEEP_REMAP {tkeep[2:0]} CONFIG.TLAST_REMAP {tlast[0]} CONFIG.TSTRB_REMAP {1'b0} CONFIG.TUSER_REMAP {tuser[0:0]}] $cell} reason]} {
puts $audit "SET_FAILED	axis_subset_converter_3	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axis_subset_converter_3	15 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axi_vdma:6.3} axi_vdma_2
set cell [get_bd_cells axi_vdma_2]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.c_addr_width] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_2	c_addr_width	64"}
if {[lsearch -exact $props CONFIG.c_include_mm2s] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_2	c_include_mm2s	0"}
if {[lsearch -exact $props CONFIG.c_include_s2mm_dre] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_2	c_include_s2mm_dre	1"}
if {[lsearch -exact $props CONFIG.c_num_fstores] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_2	c_num_fstores	3"}
if {[lsearch -exact $props CONFIG.c_s2mm_genlock_mode] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_2	c_s2mm_genlock_mode	0"}
if {[lsearch -exact $props CONFIG.c_s2mm_linebuffer_depth] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_2	c_s2mm_linebuffer_depth	4096"}
if {[lsearch -exact $props CONFIG.c_s2mm_max_burst_length] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_2	c_s2mm_max_burst_length	128"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.c_addr_width {64} CONFIG.c_include_mm2s {0} CONFIG.c_include_s2mm_dre {1} CONFIG.c_num_fstores {3} CONFIG.c_s2mm_genlock_mode {0} CONFIG.c_s2mm_linebuffer_depth {4096} CONFIG.c_s2mm_max_burst_length {128}] $cell} reason]} {
puts $audit "SET_FAILED	axi_vdma_2	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axi_vdma_2	7 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axi_vdma:6.3} axi_vdma_3
set cell [get_bd_cells axi_vdma_3]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.c_addr_width] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_3	c_addr_width	64"}
if {[lsearch -exact $props CONFIG.c_include_mm2s] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_3	c_include_mm2s	0"}
if {[lsearch -exact $props CONFIG.c_include_s2mm_dre] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_3	c_include_s2mm_dre	1"}
if {[lsearch -exact $props CONFIG.c_num_fstores] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_3	c_num_fstores	3"}
if {[lsearch -exact $props CONFIG.c_s2mm_genlock_mode] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_3	c_s2mm_genlock_mode	0"}
if {[lsearch -exact $props CONFIG.c_s2mm_linebuffer_depth] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_3	c_s2mm_linebuffer_depth	4096"}
if {[lsearch -exact $props CONFIG.c_s2mm_max_burst_length] < 0} {incr unsupported; puts $audit "MISSING	axi_vdma_3	c_s2mm_max_burst_length	128"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.c_addr_width {64} CONFIG.c_include_mm2s {0} CONFIG.c_include_s2mm_dre {1} CONFIG.c_num_fstores {3} CONFIG.c_s2mm_genlock_mode {0} CONFIG.c_s2mm_linebuffer_depth {4096} CONFIG.c_s2mm_max_burst_length {128}] $cell} reason]} {
puts $audit "SET_FAILED	axi_vdma_3	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axi_vdma_3	7 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axi_iic:2.0} axi_iic_0
set cell [get_bd_cells axi_iic_0]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.IIC_FREQ_KHZ] < 0} {incr unsupported; puts $audit "MISSING	axi_iic_0	IIC_FREQ_KHZ	100"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.IIC_FREQ_KHZ {100}] $cell} reason]} {
puts $audit "SET_FAILED	axi_iic_0	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axi_iic_0	1 original parameters"}}
create_bd_cell -type ip -vlnv {xilinx.com:ip:axi_iic:2.0} axi_iic_1
set cell [get_bd_cells axi_iic_1]
set props [list_property $cell]
if {[lsearch -exact $props CONFIG.IIC_FREQ_KHZ] < 0} {incr unsupported; puts $audit "MISSING	axi_iic_1	IIC_FREQ_KHZ	100"}
if {$unsupported == 0} {
if {[catch {set_property -dict [list CONFIG.IIC_FREQ_KHZ {100}] $cell} reason]} {
puts $audit "SET_FAILED	axi_iic_1	$reason"; close $audit; error $reason
} else {puts $audit "SET_OK	axi_iic_1	1 original parameters"}}
close $audit
if {$unsupported} {error "Unsupported archived parameters: $unsupported; see property-audit.txt"}
set_property CONFIG.NUM_MI 12 [get_bd_cells ps8_0_axi_periph]
create_bd_cell -type module -reference hand_hil_shell hil
set_property CONFIG.CLK_HZ 200703980 [get_bd_cells hil]
create_bd_cell -type module -reference csi_delay_reference delay_reference
create_bd_intf_port -mode Master -vlnv {xilinx.com:interface:iic_rtl:1.0} csi_i2c0
create_bd_intf_port -mode Master -vlnv {xilinx.com:interface:iic_rtl:1.0} csi_i2c1
create_bd_intf_port -mode Master -vlnv {xilinx.com:interface:gpio_rtl:1.0} csi_rstn
create_bd_intf_port -mode Slave -vlnv {xilinx.com:interface:mipi_phy_rtl:1.0} mipi_phy_if_1
create_bd_intf_port -mode Slave -vlnv {xilinx.com:interface:mipi_phy_rtl:1.0} mipi_phy_if_0
create_bd_intf_port -mode Slave -vlnv {xilinx.com:interface:mipi_phy_rtl:1.0} mipi_phy_if_2
create_bd_intf_port -mode Slave -vlnv {xilinx.com:interface:mipi_phy_rtl:1.0} mipi_phy_if_3
create_bd_intf_port -mode Master -vlnv {xilinx.com:interface:iic_rtl:1.0} csi_i2c2
create_bd_intf_port -mode Master -vlnv {xilinx.com:interface:iic_rtl:1.0} csi_i2c3
connect_bd_intf_net -intf_net {AXI_BayerToRGB_3_AXI_Stream_Master} [get_bd_intf_pins {AXI_BayerToRGB_3/AXI_Stream_Master}] [get_bd_intf_pins {AXI_GammaCorrection_3/AXI_Slave_Interface}]
connect_bd_intf_net -intf_net {axis_subset_converter_2_M_AXIS} [get_bd_intf_pins {axis_subset_converter_2/M_AXIS}] [get_bd_intf_pins {axi_vdma_2/S_AXIS_S2MM}]
connect_bd_intf_net -intf_net {csi_4lane_raw10_3_m_axis_video} [get_bd_intf_pins {csi_4lane_raw10_3/m_axis_video}] [get_bd_intf_pins {AXI_BayerToRGB_3/AXI_Slave_Interface}]
connect_bd_intf_net -intf_net {AXI_GammaCorrection_0_AXI_Stream_Master} [get_bd_intf_pins {AXI_GammaCorrection_0/AXI_Stream_Master}] [get_bd_intf_pins {axis_subset_converter_0/S_AXIS}]
connect_bd_intf_net -intf_net {axi_vdma_2_M_AXI_S2MM} [get_bd_intf_pins {axi_vdma_2/M_AXI_S2MM}] [get_bd_intf_pins {smartconnect_0/S02_AXI}]
connect_bd_intf_net -intf_net {csi_4lane_raw10_2_m_axis_video} [get_bd_intf_pins {csi_4lane_raw10_2/m_axis_video}] [get_bd_intf_pins {AXI_BayerToRGB_2/AXI_Slave_Interface}]
connect_bd_intf_net -intf_net {axi_iic_1_IIC} [get_bd_intf_ports {csi_i2c3}] [get_bd_intf_pins {axi_iic_1/IIC}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M05_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M05_AXI}] [get_bd_intf_pins {AXI_GammaCorrection_2/AXI_Lite_Reg_Intf}]
connect_bd_intf_net -intf_net {AXI_BayerToRGB_2_AXI_Stream_Master} [get_bd_intf_pins {AXI_BayerToRGB_2/AXI_Stream_Master}] [get_bd_intf_pins {AXI_GammaCorrection_2/AXI_Slave_Interface}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M06_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M06_AXI}] [get_bd_intf_pins {AXI_GammaCorrection_3/AXI_Lite_Reg_Intf}]
connect_bd_intf_net -intf_net {axi_vdma_3_M_AXI_S2MM} [get_bd_intf_pins {axi_vdma_3/M_AXI_S2MM}] [get_bd_intf_pins {smartconnect_0/S03_AXI}]
connect_bd_intf_net -intf_net {mipi_phy_if_2_1} [get_bd_intf_ports {mipi_phy_if_2}] [get_bd_intf_pins {csi_4lane_raw10_2/mipi_phy_if}]
connect_bd_intf_net -intf_net {axis_subset_converter_3_M_AXIS} [get_bd_intf_pins {axis_subset_converter_3/M_AXIS}] [get_bd_intf_pins {axi_vdma_3/S_AXIS_S2MM}]
connect_bd_intf_net -intf_net {AXI_GammaCorrection_2_AXI_Stream_Master} [get_bd_intf_pins {AXI_GammaCorrection_2/AXI_Stream_Master}] [get_bd_intf_pins {axis_subset_converter_2/S_AXIS}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M08_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M08_AXI}] [get_bd_intf_pins {axi_vdma_3/S_AXI_LITE}]
connect_bd_intf_net -intf_net {S00_AXI_1} [get_bd_intf_pins {ps8_0_axi_periph/S00_AXI}] [get_bd_intf_pins {zynq_ultra_ps_e_0/M_AXI_HPM0_FPD}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M10_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M10_AXI}] [get_bd_intf_pins {axi_iic_1/S_AXI}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M01_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M01_AXI}] [get_bd_intf_pins {csi_rst/S_AXI}]
connect_bd_intf_net -intf_net {mipi_phy_if_1_1} [get_bd_intf_ports {mipi_phy_if_1}] [get_bd_intf_pins {csi_4lane_raw10_1/mipi_phy_if}]
connect_bd_intf_net -intf_net {zynq_ultra_ps_e_0_IIC_1} [get_bd_intf_ports {csi_i2c1}] [get_bd_intf_pins {zynq_ultra_ps_e_0/IIC_1}]
connect_bd_intf_net -intf_net {AXI_BayerToRGB_0_AXI_Stream_Master} [get_bd_intf_pins {AXI_BayerToRGB_0/AXI_Stream_Master}] [get_bd_intf_pins {AXI_GammaCorrection_0/AXI_Slave_Interface}]
connect_bd_intf_net -intf_net {mipi_phy_if_0_1} [get_bd_intf_ports {mipi_phy_if_0}] [get_bd_intf_pins {csi_4lane_raw10_0/mipi_phy_if}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M09_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M09_AXI}] [get_bd_intf_pins {axi_iic_0/S_AXI}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M07_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M07_AXI}] [get_bd_intf_pins {axi_vdma_2/S_AXI_LITE}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M04_AXI} [get_bd_intf_pins {AXI_GammaCorrection_1/AXI_Lite_Reg_Intf}] [get_bd_intf_pins {ps8_0_axi_periph/M04_AXI}]
connect_bd_intf_net -intf_net {csi_4lane_raw10_0_m_axis_video} [get_bd_intf_pins {csi_4lane_raw10_0/m_axis_video}] [get_bd_intf_pins {AXI_BayerToRGB_0/AXI_Slave_Interface}]
connect_bd_intf_net -intf_net {axi_iic_0_IIC} [get_bd_intf_ports {csi_i2c2}] [get_bd_intf_pins {axi_iic_0/IIC}]
connect_bd_intf_net -intf_net {smartconnect_0_M00_AXI1} [get_bd_intf_pins {smartconnect_0/M00_AXI}] [get_bd_intf_pins {zynq_ultra_ps_e_0/S_AXI_HP1_FPD}]
connect_bd_intf_net -intf_net {mipi_phy_if_3_1} [get_bd_intf_ports {mipi_phy_if_3}] [get_bd_intf_pins {csi_4lane_raw10_3/mipi_phy_if}]
connect_bd_intf_net -intf_net {AXI_BayerToRGB_1_AXI_Stream_Master} [get_bd_intf_pins {AXI_BayerToRGB_1/AXI_Stream_Master}] [get_bd_intf_pins {AXI_GammaCorrection_1/AXI_Slave_Interface}]
connect_bd_intf_net -intf_net {axis_subset_converter_1_M_AXIS} [get_bd_intf_pins {axis_subset_converter_1/M_AXIS}] [get_bd_intf_pins {axi_vdma_1/S_AXIS_S2MM}]
connect_bd_intf_net -intf_net {csi_4lane_raw10_1_m_axis_video} [get_bd_intf_pins {csi_4lane_raw10_1/m_axis_video}] [get_bd_intf_pins {AXI_BayerToRGB_1/AXI_Slave_Interface}]
connect_bd_intf_net -intf_net {axis_subset_converter_0_M_AXIS} [get_bd_intf_pins {axis_subset_converter_0/M_AXIS}] [get_bd_intf_pins {axi_vdma_0/S_AXIS_S2MM}]
connect_bd_intf_net -intf_net {AXI_GammaCorrection_1_AXI_Stream_Master} [get_bd_intf_pins {AXI_GammaCorrection_1/AXI_Stream_Master}] [get_bd_intf_pins {axis_subset_converter_1/S_AXIS}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M02_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M02_AXI}] [get_bd_intf_pins {axi_vdma_1/S_AXI_LITE}]
connect_bd_intf_net -intf_net {axi_vdma_1_M_AXI_S2MM} [get_bd_intf_pins {axi_vdma_1/M_AXI_S2MM}] [get_bd_intf_pins {smartconnect_0/S01_AXI}]
connect_bd_intf_net -intf_net {axi_vdma_0_M_AXI_S2MM} [get_bd_intf_pins {axi_vdma_0/M_AXI_S2MM}] [get_bd_intf_pins {smartconnect_0/S00_AXI}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M00_AXI} [get_bd_intf_pins {ps8_0_axi_periph/M00_AXI}] [get_bd_intf_pins {axi_vdma_0/S_AXI_LITE}]
connect_bd_intf_net -intf_net {ps8_0_axi_periph_M03_AXI} [get_bd_intf_pins {AXI_GammaCorrection_0/AXI_Lite_Reg_Intf}] [get_bd_intf_pins {ps8_0_axi_periph/M03_AXI}]
connect_bd_intf_net -intf_net {cmos_rst_GPIO} [get_bd_intf_ports {csi_rstn}] [get_bd_intf_pins {csi_rst/GPIO}]
connect_bd_intf_net -intf_net {AXI_GammaCorrection_3_AXI_Stream_Master} [get_bd_intf_pins {AXI_GammaCorrection_3/AXI_Stream_Master}] [get_bd_intf_pins {axis_subset_converter_3/S_AXIS}]
connect_bd_intf_net -intf_net {zynq_ultra_ps_e_0_IIC_0} [get_bd_intf_ports {csi_i2c0}] [get_bd_intf_pins {zynq_ultra_ps_e_0/IIC_0}]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M11_AXI] [get_bd_intf_pins hil/s_axi]
connect_bd_net -net {zynq_ultra_ps_e_0_pl_clk0} [get_bd_pins {zynq_ultra_ps_e_0/pl_clk0}] [get_bd_pins {AXI_GammaCorrection_0/StreamClk}] [get_bd_pins {AXI_GammaCorrection_0/AxiLiteClk}] [get_bd_pins {AXI_GammaCorrection_1/StreamClk}] [get_bd_pins {AXI_GammaCorrection_1/AxiLiteClk}] [get_bd_pins {csi_rst/s_axi_aclk}] [get_bd_pins {axi_vdma_0/s_axi_lite_aclk}] [get_bd_pins {axi_vdma_0/m_axi_s2mm_aclk}] [get_bd_pins {axi_vdma_0/s_axis_s2mm_aclk}] [get_bd_pins {axi_vdma_1/s_axi_lite_aclk}] [get_bd_pins {axi_vdma_1/m_axi_s2mm_aclk}] [get_bd_pins {axi_vdma_1/s_axis_s2mm_aclk}] [get_bd_pins {axis_subset_converter_0/aclk}] [get_bd_pins {axis_subset_converter_1/aclk}] [get_bd_pins {csi_4lane_raw10_0/ref_clock_in}] [get_bd_pins {csi_4lane_raw10_0/m_axis_video_aclk}] [get_bd_pins {csi_4lane_raw10_1/ref_clock_in}] [get_bd_pins {csi_4lane_raw10_1/m_axis_video_aclk}] [get_bd_pins {proc_sys_reset_100M/slowest_sync_clk}] [get_bd_pins {ps8_0_axi_periph/ACLK}] [get_bd_pins {ps8_0_axi_periph/S00_ACLK}] [get_bd_pins {ps8_0_axi_periph/M00_ACLK}] [get_bd_pins {ps8_0_axi_periph/M01_ACLK}] [get_bd_pins {ps8_0_axi_periph/M02_ACLK}] [get_bd_pins {ps8_0_axi_periph/M03_ACLK}] [get_bd_pins {ps8_0_axi_periph/M04_ACLK}] [get_bd_pins {zynq_ultra_ps_e_0/maxihpm0_fpd_aclk}] [get_bd_pins {zynq_ultra_ps_e_0/saxihp1_fpd_aclk}] [get_bd_pins {smartconnect_0/aclk}] [get_bd_pins {ps8_0_axi_periph/M05_ACLK}] [get_bd_pins {system_ila_0/clk}] [get_bd_pins {system_ila_1/clk}] [get_bd_pins {AXI_BayerToRGB_0/StreamClk}] [get_bd_pins {AXI_BayerToRGB_1/StreamClk}] [get_bd_pins {axis_pixel_counter_0/aclk}] [get_bd_pins {AXI_BayerToRGB_2/StreamClk}] [get_bd_pins {AXI_GammaCorrection_2/StreamClk}] [get_bd_pins {csi_4lane_raw10_2/m_axis_video_aclk}] [get_bd_pins {AXI_BayerToRGB_3/StreamClk}] [get_bd_pins {AXI_GammaCorrection_3/StreamClk}] [get_bd_pins {csi_4lane_raw10_3/m_axis_video_aclk}] [get_bd_pins {AXI_GammaCorrection_2/AxiLiteClk}] [get_bd_pins {AXI_GammaCorrection_3/AxiLiteClk}] [get_bd_pins {ps8_0_axi_periph/M06_ACLK}] [get_bd_pins {axi_vdma_2/m_axi_s2mm_aclk}] [get_bd_pins {axi_vdma_2/s_axi_lite_aclk}] [get_bd_pins {ps8_0_axi_periph/M07_ACLK}] [get_bd_pins {axi_vdma_2/s_axis_s2mm_aclk}] [get_bd_pins {axis_subset_converter_2/aclk}] [get_bd_pins {axi_vdma_3/m_axi_s2mm_aclk}] [get_bd_pins {axi_vdma_3/s_axi_lite_aclk}] [get_bd_pins {ps8_0_axi_periph/M08_ACLK}] [get_bd_pins {axi_vdma_3/s_axis_s2mm_aclk}] [get_bd_pins {axis_subset_converter_3/aclk}] [get_bd_pins {csi_4lane_raw10_2/ref_clock_in}] [get_bd_pins {csi_4lane_raw10_3/ref_clock_in}] [get_bd_pins {axi_iic_0/s_axi_aclk}] [get_bd_pins {ps8_0_axi_periph/M09_ACLK}] [get_bd_pins {axi_iic_1/s_axi_aclk}] [get_bd_pins {ps8_0_axi_periph/M10_ACLK}] [get_bd_pins {hil/clk}] [get_bd_pins {ps8_0_axi_periph/M11_ACLK}] [get_bd_pins {delay_reference/clk_pl0}]
connect_bd_net -net {zynq_ultra_ps_e_0_pl_resetn0} [get_bd_pins {zynq_ultra_ps_e_0/pl_resetn0}] [get_bd_pins {proc_sys_reset_100M/ext_reset_in}]
connect_bd_net -net {proc_sys_reset_100M_peripheral_aresetn} [get_bd_pins {proc_sys_reset_100M/peripheral_aresetn}] [get_bd_pins {AXI_GammaCorrection_0/sStreamReset_n}] [get_bd_pins {AXI_GammaCorrection_0/aAxiLiteReset_n}] [get_bd_pins {AXI_GammaCorrection_1/sStreamReset_n}] [get_bd_pins {AXI_GammaCorrection_1/aAxiLiteReset_n}] [get_bd_pins {csi_rst/s_axi_aresetn}] [get_bd_pins {axi_vdma_0/axi_resetn}] [get_bd_pins {axi_vdma_1/axi_resetn}] [get_bd_pins {csi_4lane_raw10_0/m_axis_video_aresetn}] [get_bd_pins {csi_4lane_raw10_1/m_axis_video_aresetn}] [get_bd_pins {ps8_0_axi_periph/S00_ARESETN}] [get_bd_pins {ps8_0_axi_periph/M00_ARESETN}] [get_bd_pins {ps8_0_axi_periph/M01_ARESETN}] [get_bd_pins {ps8_0_axi_periph/M02_ARESETN}] [get_bd_pins {ps8_0_axi_periph/M03_ARESETN}] [get_bd_pins {ps8_0_axi_periph/M04_ARESETN}] [get_bd_pins {smartconnect_0/aresetn}] [get_bd_pins {ps8_0_axi_periph/M05_ARESETN}] [get_bd_pins {AXI_BayerToRGB_0/sStreamReset_n}] [get_bd_pins {AXI_BayerToRGB_1/sStreamReset_n}] [get_bd_pins {axis_pixel_counter_0/aresetn}] [get_bd_pins {AXI_BayerToRGB_2/sStreamReset_n}] [get_bd_pins {AXI_GammaCorrection_2/sStreamReset_n}] [get_bd_pins {csi_4lane_raw10_2/m_axis_video_aresetn}] [get_bd_pins {AXI_BayerToRGB_3/sStreamReset_n}] [get_bd_pins {AXI_GammaCorrection_3/sStreamReset_n}] [get_bd_pins {csi_4lane_raw10_3/m_axis_video_aresetn}] [get_bd_pins {AXI_GammaCorrection_2/aAxiLiteReset_n}] [get_bd_pins {AXI_GammaCorrection_3/aAxiLiteReset_n}] [get_bd_pins {ps8_0_axi_periph/M06_ARESETN}] [get_bd_pins {axi_vdma_2/axi_resetn}] [get_bd_pins {ps8_0_axi_periph/M07_ARESETN}] [get_bd_pins {axis_subset_converter_2/aresetn}] [get_bd_pins {axi_vdma_3/axi_resetn}] [get_bd_pins {ps8_0_axi_periph/M08_ARESETN}] [get_bd_pins {axis_subset_converter_3/aresetn}] [get_bd_pins {axi_iic_0/s_axi_aresetn}] [get_bd_pins {ps8_0_axi_periph/M09_ARESETN}] [get_bd_pins {axi_iic_1/s_axi_aresetn}] [get_bd_pins {ps8_0_axi_periph/M10_ARESETN}] [get_bd_pins {hil/rst_n}] [get_bd_pins {ps8_0_axi_periph/M11_ARESETN}]
connect_bd_net -net {proc_sys_reset_100M_interconnect_aresetn} [get_bd_pins {proc_sys_reset_100M/interconnect_aresetn}] [get_bd_pins {ps8_0_axi_periph/ARESETN}]
connect_bd_net -net {xlconstant_0_dout} [get_bd_pins {xlconstant_0/dout}] [get_bd_pins {axis_subset_converter_0/aresetn}] [get_bd_pins {axis_subset_converter_1/aresetn}]
connect_bd_net -net {proc_sys_reset_100M_peripheral_reset} [get_bd_pins {proc_sys_reset_100M/peripheral_reset}] [get_bd_pins {csi_4lane_raw10_0/reset}] [get_bd_pins {csi_4lane_raw10_1/reset}] [get_bd_pins {csi_4lane_raw10_2/reset}] [get_bd_pins {csi_4lane_raw10_3/reset}] [get_bd_pins {delay_reference/reset}]
connect_bd_net -net {xlconcat_3_dout} [get_bd_pins {xlconcat_3/dout}] [get_bd_pins {zynq_ultra_ps_e_0/pl_ps_irq1}]
connect_bd_net -net {axis_subset_converter_0_m_axis_tdata} [get_bd_pins {axis_subset_converter_0/m_axis_tdata}] [get_bd_pins {axi_vdma_0/s_axis_s2mm_tdata}]
connect_bd_net -net {axis_subset_converter_0_m_axis_tkeep} [get_bd_pins {axis_subset_converter_0/m_axis_tkeep}] [get_bd_pins {axi_vdma_0/s_axis_s2mm_tkeep}]
connect_bd_net -net {axis_subset_converter_0_m_axis_tlast} [get_bd_pins {axis_subset_converter_0/m_axis_tlast}] [get_bd_pins {axi_vdma_0/s_axis_s2mm_tlast}]
connect_bd_net -net {axi_vdma_0_s_axis_s2mm_tready} [get_bd_pins {axi_vdma_0/s_axis_s2mm_tready}] [get_bd_pins {axis_subset_converter_0/m_axis_tready}]
connect_bd_net -net {axis_subset_converter_0_m_axis_tuser} [get_bd_pins {axis_subset_converter_0/m_axis_tuser}] [get_bd_pins {axi_vdma_0/s_axis_s2mm_tuser}]
connect_bd_net -net {axis_subset_converter_0_m_axis_tvalid} [get_bd_pins {axis_subset_converter_0/m_axis_tvalid}] [get_bd_pins {axi_vdma_0/s_axis_s2mm_tvalid}]
connect_bd_net -net {axi_vdma_0_s2mm_introut} [get_bd_pins {axi_vdma_0/s2mm_introut}] [get_bd_pins {xlconcat_3/In0}]
connect_bd_net -net {axi_vdma_1_s2mm_introut} [get_bd_pins {axi_vdma_1/s2mm_introut}] [get_bd_pins {xlconcat_3/In1}]
connect_bd_net -net {width_latch} [get_bd_pins {axis_pixel_counter_0/width_latch}] [get_bd_pins {system_ila_0/probe11}]
connect_bd_net -net {row_cnt} [get_bd_pins {axis_pixel_counter_0/row_cnt}] [get_bd_pins {system_ila_0/probe9}]
connect_bd_net -net {sof_pulse} [get_bd_pins {axis_pixel_counter_0/sof_pulse}] [get_bd_pins {system_ila_0/probe10}]
connect_bd_net -net {csi_4lane_raw10_0_m_axis_video_tdata} [get_bd_pins {csi_4lane_raw10_0/m_axis_video_tdata}] [get_bd_pins {system_ila_1/probe0}] [get_bd_pins {AXI_BayerToRGB_0/s_axis_video_tdata}] [get_bd_pins {axis_pixel_counter_0/s_axis_tdata}]
connect_bd_net -net {csi_4lane_raw10_0_m_axis_video_tlast} [get_bd_pins {csi_4lane_raw10_0/m_axis_video_tlast}] [get_bd_pins {system_ila_1/probe1}] [get_bd_pins {AXI_BayerToRGB_0/s_axis_video_tlast}] [get_bd_pins {axis_pixel_counter_0/s_axis_tlast}]
connect_bd_net -net {csi_4lane_raw10_0_m_axis_video_tuser} [get_bd_pins {csi_4lane_raw10_0/m_axis_video_tuser}] [get_bd_pins {system_ila_1/probe2}] [get_bd_pins {AXI_BayerToRGB_0/s_axis_video_tuser}] [get_bd_pins {axis_pixel_counter_0/s_axis_tuser}]
connect_bd_net -net {csi_4lane_raw10_0_m_axis_video_tvalid} [get_bd_pins {csi_4lane_raw10_0/m_axis_video_tvalid}] [get_bd_pins {system_ila_1/probe3}] [get_bd_pins {AXI_BayerToRGB_0/s_axis_video_tvalid}] [get_bd_pins {axis_pixel_counter_0/s_axis_tvalid}]
connect_bd_net -net {AXI_BayerToRGB_0_s_axis_video_tready} [get_bd_pins {AXI_BayerToRGB_0/s_axis_video_tready}] [get_bd_pins {csi_4lane_raw10_0/m_axis_video_tready}] [get_bd_pins {system_ila_1/probe4}] [get_bd_pins {axis_pixel_counter_0/s_axis_tready}]
connect_bd_net -net {pixel_cnt_lo} [get_bd_pins {axis_pixel_counter_0/pixel_cnt_lo}] [get_bd_pins {system_ila_0/probe8}]
connect_bd_net -net {pixel_cnt_hi} [get_bd_pins {axis_pixel_counter_0/pixel_cnt_hi}] [get_bd_pins {system_ila_0/probe7}]
connect_bd_net -net {frame_period_lo} [get_bd_pins {axis_pixel_counter_0/frame_period_lo}] [get_bd_pins {system_ila_0/probe5}]
connect_bd_net -net {frame_period_hi} [get_bd_pins {axis_pixel_counter_0/frame_period_hi}] [get_bd_pins {system_ila_0/probe4}]
connect_bd_net -net {height_latch} [get_bd_pins {axis_pixel_counter_0/height_latch}] [get_bd_pins {system_ila_0/probe6}]
connect_bd_net -net {frame_cnt} [get_bd_pins {axis_pixel_counter_0/frame_cnt}] [get_bd_pins {system_ila_0/probe3}]
connect_bd_net -net {eol_pulse} [get_bd_pins {axis_pixel_counter_0/eol_pulse}] [get_bd_pins {system_ila_0/probe2}]
connect_bd_net -net {col_cnt} [get_bd_pins {axis_pixel_counter_0/col_cnt}] [get_bd_pins {system_ila_0/probe0}]
connect_bd_net -net {eof_pulse} [get_bd_pins {axis_pixel_counter_0/eof_pulse}] [get_bd_pins {system_ila_0/probe1}]
connect_bd_net -net {axi_vdma_2_s2mm_introut} [get_bd_pins {axi_vdma_2/s2mm_introut}] [get_bd_pins {xlconcat_3/In2}]
connect_bd_net -net {axi_vdma_3_s2mm_introut} [get_bd_pins {axi_vdma_3/s2mm_introut}] [get_bd_pins {xlconcat_3/In3}]
connect_bd_net -net {axi_iic_0_iic2intc_irpt} [get_bd_pins {axi_iic_0/iic2intc_irpt}] [get_bd_pins {xlconcat_3/In4}]
connect_bd_net -net {axi_iic_1_iic2intc_irpt} [get_bd_pins {axi_iic_1/iic2intc_irpt}] [get_bd_pins {xlconcat_3/In5}]
connect_bd_net [get_bd_pins delay_reference/refclk] [get_bd_pins csi_4lane_raw10_0/delay_refclock] [get_bd_pins csi_4lane_raw10_1/delay_refclock] [get_bd_pins csi_4lane_raw10_2/delay_refclock] [get_bd_pins csi_4lane_raw10_3/delay_refclock]
connect_bd_net [get_bd_pins delay_reference/io_reset] [get_bd_pins csi_4lane_raw10_0/io_reset] [get_bd_pins csi_4lane_raw10_1/io_reset] [get_bd_pins csi_4lane_raw10_2/io_reset] [get_bd_pins csi_4lane_raw10_3/io_reset]
connect_bd_net [get_bd_pins delay_reference/delay_reset] [get_bd_pins csi_4lane_raw10_0/delay_reset] [get_bd_pins csi_4lane_raw10_1/delay_reset] [get_bd_pins csi_4lane_raw10_2/delay_reset] [get_bd_pins csi_4lane_raw10_3/delay_reset]
connect_bd_net [get_bd_pins delay_reference/all_ready] [get_bd_pins csi_4lane_raw10_0/all_ready] [get_bd_pins csi_4lane_raw10_1/all_ready] [get_bd_pins csi_4lane_raw10_2/all_ready] [get_bd_pins csi_4lane_raw10_3/all_ready]
connect_bd_net [get_bd_pins csi_4lane_raw10_0/delay_ready] [get_bd_pins delay_reference/ready0]
connect_bd_net [get_bd_pins csi_4lane_raw10_1/delay_ready] [get_bd_pins delay_reference/ready1]
connect_bd_net [get_bd_pins csi_4lane_raw10_2/delay_ready] [get_bd_pins delay_reference/ready2]
connect_bd_net [get_bd_pins csi_4lane_raw10_3/delay_ready] [get_bd_pins delay_reference/ready3]
assign_bd_address -offset 0x0000000800000000 -range 32G -target_address_space [get_bd_addr_spaces {/axi_vdma_0/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_HIGH}]
assign_bd_address -offset 0x0000000000000000 -range 2G -target_address_space [get_bd_addr_spaces {/axi_vdma_0/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW}]
exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces {/axi_vdma_0/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_LPS_OCM}]
assign_bd_address -offset 0x00000000E0000000 -range 256M -target_address_space [get_bd_addr_spaces {/axi_vdma_0/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_PCIE_LOW}]
assign_bd_address -offset 0x00000000C0000000 -range 512M -target_address_space [get_bd_addr_spaces {/axi_vdma_0/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_QSPI}]
assign_bd_address -offset 0x0000000800000000 -range 32G -target_address_space [get_bd_addr_spaces {/axi_vdma_1/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_HIGH}]
assign_bd_address -offset 0x0000000000000000 -range 2G -target_address_space [get_bd_addr_spaces {/axi_vdma_1/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW}]
exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces {/axi_vdma_1/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_LPS_OCM}]
assign_bd_address -offset 0x00000000E0000000 -range 256M -target_address_space [get_bd_addr_spaces {/axi_vdma_1/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_PCIE_LOW}]
assign_bd_address -offset 0x00000000C0000000 -range 512M -target_address_space [get_bd_addr_spaces {/axi_vdma_1/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_QSPI}]
assign_bd_address -offset 0x00A0040000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/AXI_GammaCorrection_0/AXI_Lite_Reg_Intf/Reg}]
assign_bd_address -offset 0x00A0050000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/AXI_GammaCorrection_1/AXI_Lite_Reg_Intf/Reg}]
assign_bd_address -offset 0x00A0000000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/AXI_GammaCorrection_2/AXI_Lite_Reg_Intf/Reg}]
assign_bd_address -offset 0x00A0010000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/AXI_GammaCorrection_3/AXI_Lite_Reg_Intf/Reg}]
assign_bd_address -offset 0x00A0090000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/axi_iic_0/S_AXI/Reg}]
assign_bd_address -offset 0x00A00A0000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/axi_iic_1/S_AXI/Reg}]
assign_bd_address -offset 0x00A0060000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/axi_vdma_0/S_AXI_LITE/Reg}]
assign_bd_address -offset 0x00A0070000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/axi_vdma_1/S_AXI_LITE/Reg}]
assign_bd_address -offset 0x00A0020000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/axi_vdma_2/S_AXI_LITE/Reg}]
assign_bd_address -offset 0x00A0030000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/axi_vdma_3/S_AXI_LITE/Reg}]
assign_bd_address -offset 0x00A0080000 -range 64K -target_address_space [get_bd_addr_spaces {/zynq_ultra_ps_e_0/Data}] [get_bd_addr_segs {/csi_rst/S_AXI/Reg}]
assign_bd_address -offset 0x0000000800000000 -range 32G -target_address_space [get_bd_addr_spaces {/axi_vdma_2/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_HIGH}]
assign_bd_address -offset 0x0000000000000000 -range 2G -target_address_space [get_bd_addr_spaces {/axi_vdma_2/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW}]
exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces {/axi_vdma_2/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_LPS_OCM}]
assign_bd_address -offset 0x00000000E0000000 -range 256M -target_address_space [get_bd_addr_spaces {/axi_vdma_2/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_PCIE_LOW}]
assign_bd_address -offset 0x00000000C0000000 -range 512M -target_address_space [get_bd_addr_spaces {/axi_vdma_2/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_QSPI}]
assign_bd_address -offset 0x0000000800000000 -range 32G -target_address_space [get_bd_addr_spaces {/axi_vdma_3/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_HIGH}]
assign_bd_address -offset 0x0000000000000000 -range 2G -target_address_space [get_bd_addr_spaces {/axi_vdma_3/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW}]
exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces {/axi_vdma_3/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_LPS_OCM}]
assign_bd_address -offset 0x00000000E0000000 -range 256M -target_address_space [get_bd_addr_spaces {/axi_vdma_3/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_PCIE_LOW}]
assign_bd_address -offset 0x00000000C0000000 -range 512M -target_address_space [get_bd_addr_spaces {/axi_vdma_3/Data_S2MM}] [get_bd_addr_segs {/zynq_ultra_ps_e_0/SAXIGP3/HP1_QSPI}]
assign_bd_address -offset 0xA1000000 -range 4K -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs -of_objects [get_bd_intf_pins hil/s_axi]]
validate_bd_design
save_bd_design
file copy -force [get_property NAME [get_files design_1.bd]] [file join $out source {mipi_dp.srcs/sources_1/bd/design_1/design_1.bd}]
write_bd_tcl [file join $out camera_hil_bd.tcl]
report_ip_status -file [file join $out ip_status.rpt]
set f [open [file join $out validated.txt] w]; puts $f "Vivado 2020.1 validate_bd_design returned successfully"; close $f
generate_target all [get_files design_1.bd]
add_files -norecurse [file join $out source {mipi_dp.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v}]
add_files -fileset constrs_1 -norecurse [file join $out source {mipi_dp.srcs/constrs_1/new/system.xdc}]
add_files -fileset constrs_1 -norecurse [file join $out source {mipi_dp.srcs/constrs_1/new/mipi.xdc}]
add_files -fileset constrs_1 -norecurse [file join $out source {mipi_dp.srcs/constrs_1/new/QSFP.xdc}]
add_files -fileset constrs_1 -norecurse [file join $out source {mipi_dp.srcs/constrs_1/new/ddr4_set.xdc}]
add_files -fileset constrs_1 -norecurse [file join $out source {mipi_dp.srcs/constrs_1/new/mipi2.xdc}]
add_files -fileset constrs_1 -norecurse [file join $out mipi_nominal.xdc]
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "experimental synthesis failed"}
open_run synth_1
report_utilization -file [file join $out utilization_synth.rpt]
set clk [get_clocks clk_pl_0]
if {[llength $clk] != 1 || [llength [get_property SOURCE_PINS $clk]] != 1} {error "Expected original single-source PS clock"}
puts "ORIGINAL_CLOCK_SOURCE clk_pl_0 [get_property SOURCE_PINS $clk]"
set clk [get_clocks clk_pl_1]
if {[llength $clk] != 1 || [llength [get_property SOURCE_PINS $clk]] != 1} {error "Expected original single-source PS clock"}
puts "ORIGINAL_CLOCK_SOURCE clk_pl_1 [get_property SOURCE_PINS $clk]"
close_design
add_files -fileset constrs_1 -norecurse [file join $out live_clock.xdc]
set_property USED_IN_SYNTHESIS false [get_files live_clock.xdc]
set_property PROCESSING_ORDER LATE [get_files live_clock.xdc]
set_property STEPS.OPT_DESIGN.TCL.POST [file join $out fix_netlist.tcl] [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.TCL.POST [file join $out fix_netlist.tcl] [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "experimental implementation failed"}
open_run impl_1
report_clocks -file [file join $out clocks_impl.rpt]
set cf [open [file join $out clock_sources.txt] w]
set clk [get_clocks clk_pl_0]
if {[llength $clk] != 1 || [llength [get_property SOURCE_PINS $clk]] != 1} {error "Final PL clock must have one source"}
puts $cf "clk_pl_0	[get_property PERIOD $clk]	[get_property SOURCE_PINS $clk]"
set clk [get_clocks clk_pl_1]
if {[llength $clk] != 1 || [llength [get_property SOURCE_PINS $clk]] != 1} {error "Final PL clock must have one source"}
puts $cf "clk_pl_1	[get_property PERIOD $clk]	[get_property SOURCE_PINS $clk]"
close $cf
report_timing_summary -report_unconstrained -file [file join $out timing_impl.rpt]
check_timing -verbose -file [file join $out coverage_details.rpt]
report_cdc -details -file [file join $out cdc_impl.rpt]
set pf [open [file join $out delay_primitives.txt] w]
foreach c [get_cells -hier -filter {REF_NAME == IDELAYCTRL}] {puts $pf "$c REFCLK=[get_clocks -of_objects [get_pins $c/REFCLK]]"}
foreach c [get_cells -hier -filter {REF_NAME == IDELAYE3}] {puts $pf "$c FORMAT=[get_property DELAY_FORMAT $c] REFCLK_MHZ=[get_property REFCLK_FREQUENCY $c]"}
close $pf
report_drc -file [file join $out drc_impl.rpt]
report_methodology -file [file join $out methodology_impl.rpt]
write_hw_platform -fixed -include_bit [file join $out camera_hil.xsa]
puts "EXPERIMENTAL_CAMERA_HIL_DONE stage=impl; not board validated"
