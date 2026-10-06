# ============================================================================
# build_project.tcl — Vivado 2020.1 可复现的模块级仿真入口
#
# 用法：vivado -mode batch -source build_project.tcl -tclargs sim [输出目录]
#
# 仿真按顺序运行协议、总线调度、抓取状态机，检查断言和完成标记。
# 当前尚无 PS/AXI BD、官方 DDR preset 和已核验整板约束，不能生成可加载 XSA。
# 不覆盖已存在的工程目录；未指定目录时放在 fpga/build/out/<时间戳>。
# ============================================================================
if {$argc < 1 || [lindex $argv 0] ne "sim" || $argc > 2} {
    puts stderr {Only module simulation is available: -tclargs sim [output_dir]. Board build requires PS/AXI BD and verified constraints.}
    exit 1
}
set PRJ   "amazinghand_z19"
set PART  "xczu19eg-ffvc1760-2-i"
set ROOT  [file normalize [file join [file dirname [info script]] ..]]
if {$argc == 2} {
    set OUT [file normalize [lindex $argv 1]]
} else {
    set OUT [file join $ROOT build out [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]]
}
if {[file exists $OUT]} {
    puts stderr "Output directory already exists; choose a new directory: $OUT"
    exit 1
}
if {[catch {
    create_project $PRJ $OUT -part $PART
    # 尚未验证的整板顶层/AXI/UART不混入字节级模块测试。
    foreach src {scs_protocol.sv servo_bus_ctrl.sv grasp_fsm.sv} {
        add_files -fileset sources_1 [file join $ROOT rtl $src]
    }
    add_files -fileset sim_1 [glob [file join $ROOT sim *.sv]]
    set_property top servo_bus_ctrl [get_filesets sources_1]
    set_property -name xsim.elaborate.xelab.more_options -value {--timescale 1ns/1ps} -objects [get_filesets sim_1]
    set_property xsim.elaborate.debug_level off [get_filesets sim_1]
    set_property xsim.simulate.runtime all [get_filesets sim_1]
    set_property xsim.simulate.log_all_signals false [get_filesets sim_1]
    foreach tb {tb_scs_protocol tb_servo_bus tb_grasp_fsm} {
        set_property top $tb [get_filesets sim_1]
        update_compile_order -fileset sim_1
        launch_simulation -simset sim_1 -mode behavioral
        close_sim
        set logfile [file join $OUT ${PRJ}.sim sim_1 behav xsim simulate.log]
        set fh [open $logfile r]
        set result [read $fh]
        close $fh
        # XSim遇到$error可能仍返回0，必须同时检查日志和完成标记。
        if {[regexp -line {^(Error:|Fatal:|ERROR:|FATAL:)} $result] ||
            [string first "$tb: ALL PASS" $result] < 0} {
            error "Simulation failed or did not complete: $tb (see $logfile)"
        }
        file copy $logfile [file join $OUT ${tb}.log]
        puts "VERIFIED: $tb"
    }
    close_project
} failure]} {
    puts stderr $failure
    exit 1
}
puts "SIMULATION ALL PASS -> $OUT"
