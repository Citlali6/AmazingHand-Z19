# ============================================================================
# z19.xdc — ALINX Z19（XCZU19EG-2FFVC1760I）引脚与时序约束
# 引脚来源：docs/refer/Z19_key_specs.md（《Z19 用户手册》实测）
# 电平：Z19 全部 PL IO 为 HP bank ≤1.8V（FMC1 跳帽 J5 必须置 1.8V）
# 舵机总线经 TXS0108E 电平转换接 5V TTL（interface.md §2.2）
# ============================================================================

# ---- PL 系统时钟：200MHz 差分（BANK64 MRCC）----
set_property -dict {PACKAGE_PIN H24 IOSTANDARD DIFF_SSTL12_DCI} [get_ports pl_clk0_p]
set_property -dict {PACKAGE_PIN G25 IOSTANDARD DIFF_SSTL12_DCI} [get_ports pl_clk0_n]
create_clock -period 5.000 -name sys_clk [get_ports pl_clk0_p]

# ---- 舵机总线：FMC1 LA02_P（经 TXS0108E 1.8V↔5V TTL，自动方向）----
# LVCMOS18：HP bank 上限 1.8V；推挽驱动/三态由 half_duplex_uart 管理
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS18 DRIVE 8 SLEW FAST PULLUP true} [get_ports servo_data]

# ---- 心跳 LED（板载 PL_LED1）----
set_property -dict {PACKAGE_PIN B3 IOSTANDARD LVCMOS18} [get_ports heartbeat]

# ---- 预留（interface.md §2.3）：备用总线 LA02_N=K17，急停按键 PL_KEY=D4 ----
# set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS18} [get_ports servo_data_spare]
# set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS18 PULLUP true} [get_ports estop_btn]

# ---- 时序约束：跨时钟域由 sync_2ff/pulse_sync 手工约束 ----
# AXI 时钟 = clk_100（PS M_AXI_HPM0 同源），无需额外 set_clock_groups
set_false_path -from [get_ports rst_n_btn]

# ---- 位定时关键路径提示（1Mbps = 100 cyc/bit）----
# half_duplex_uart 内计数器为本设计最紧时序路径之一，综合后核对 WNS
