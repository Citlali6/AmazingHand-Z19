# NOMINAL PROFILE ONLY, not external-IO timing signoff.
# Local FL0214 REV1.0 manual p6: 25MHz buffered oscillator for both IMX214.
# Archived sensor_table.h: dual PLL 0310=1, OP prediv 030D=8,
# OP multiplier 030E/F=110, OPSYCK_DIV 030B=1.
# Sony IMX214 Software Reference 0.0.6 pp47-49:
# OPCK=25/8*110=343.75MHz, DCK=OPCK/2/1=171.875MHz; period=64/11ns.
# Bridge/PCB/oscillator tolerance and sensor output-skew remain unqualified.
# No external delay or asynchronous clock exception is invented here.
create_clock -name csi0_hs_nominal -period 5.818181818182 [get_ports mipi_phy_if_0_clk_hs_p]
create_clock -name csi1_hs_nominal -period 5.818181818182 [get_ports mipi_phy_if_1_clk_hs_p]
create_clock -name csi2_hs_nominal -period 5.818181818182 [get_ports mipi_phy_if_2_clk_hs_p]
create_clock -name csi3_hs_nominal -period 5.818181818182 [get_ports mipi_phy_if_3_clk_hs_p]
