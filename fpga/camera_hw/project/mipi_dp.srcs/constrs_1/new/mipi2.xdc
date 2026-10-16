################################################################################
# FMC2 扩展 - �? 3 路摄像头 (Camera 2) - 对应模块的左�?
# (完全等效�? FMC1 �? mipi_phy_if_0 物理相对位置)
################################################################################
set_property IOSTANDARD LVCMOS18 [get_ports mipi_phy_if_2_clk_lp_n]
set_property IOSTANDARD LVCMOS18 [get_ports mipi_phy_if_2_clk_lp_p]
set_property IOSTANDARD LVCMOS18 [get_ports {mipi_phy_if_2_data_lp_n[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {mipi_phy_if_2_data_lp_p[*]}]
set_property IOSTANDARD LVDS [get_ports mipi_phy_if_2_clk_hs_p]
set_property IOSTANDARD LVDS [get_ports {mipi_phy_if_2_data_hs_n[*]}]
set_property IOSTANDARD LVDS [get_ports {mipi_phy_if_2_data_hs_p[*]}]
set_property PULLDOWN true  [get_ports {mipi_phy_if_2_data_lp_n[*]}]
set_property PULLDOWN true  [get_ports {mipi_phy_if_2_data_lp_p[*]}]

set_property IOSTANDARD LVCMOS18 [get_ports {csi_rstn_tri_o[2]}]
# set_property IOSTANDARD LVCMOS18 [get_ports {csi_rstn_tri_o_2[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports csi_i2c2_sda_io]
set_property IOSTANDARD LVCMOS18 [get_ports csi_i2c2_scl_io]

# MIPI LP 信号引脚映射
set_property PACKAGE_PIN AV19 [get_ports mipi_phy_if_2_clk_lp_n]
set_property PACKAGE_PIN AU20 [get_ports mipi_phy_if_2_clk_lp_p]
set_property PACKAGE_PIN BB23 [get_ports {mipi_phy_if_2_data_lp_n[0]}]
set_property PACKAGE_PIN BA23 [get_ports {mipi_phy_if_2_data_lp_p[0]}]
set_property PACKAGE_PIN BB19 [get_ports {mipi_phy_if_2_data_lp_n[1]}]
set_property PACKAGE_PIN BB20 [get_ports {mipi_phy_if_2_data_lp_p[1]}]
set_property PACKAGE_PIN AL21 [get_ports {mipi_phy_if_2_data_lp_n[2]}]
set_property PACKAGE_PIN AL22 [get_ports {mipi_phy_if_2_data_lp_p[2]}]
set_property PACKAGE_PIN AW19 [get_ports {mipi_phy_if_2_data_lp_n[3]}]
set_property PACKAGE_PIN AW20 [get_ports {mipi_phy_if_2_data_lp_p[3]}]

# MIPI HS 信号引脚映射
set_property PACKAGE_PIN AV21 [get_ports mipi_phy_if_2_clk_hs_n]
set_property PACKAGE_PIN AU21 [get_ports mipi_phy_if_2_clk_hs_p]
set_property PACKAGE_PIN BA21 [get_ports {mipi_phy_if_2_data_hs_n[0]}]
set_property PACKAGE_PIN BA22 [get_ports {mipi_phy_if_2_data_hs_p[0]}]
set_property PACKAGE_PIN AP21 [get_ports {mipi_phy_if_2_data_hs_n[1]}]
set_property PACKAGE_PIN AN21 [get_ports {mipi_phy_if_2_data_hs_p[1]}]
set_property PACKAGE_PIN AK19 [get_ports {mipi_phy_if_2_data_hs_n[2]}]
set_property PACKAGE_PIN AK20 [get_ports {mipi_phy_if_2_data_hs_p[2]}]
set_property PACKAGE_PIN AV23 [get_ports {mipi_phy_if_2_data_hs_n[3]}]
set_property PACKAGE_PIN AU23 [get_ports {mipi_phy_if_2_data_hs_p[3]}]

# I2C �? 复位控制引脚映射
set_property PACKAGE_PIN AW24 [get_ports {csi_rstn_tri_o[2]}]
#set_property PACKAGE_PIN AW24 [get_ports {csi_rstn_tri_o_2[0]}]
set_property PACKAGE_PIN AY20 [get_ports csi_i2c2_scl_io]
set_property PACKAGE_PIN BA20 [get_ports csi_i2c2_sda_io]


################################################################################
# FMC2 扩展 - �? 4 路摄像头 (Camera 3) - 对应模块的右�?
# (完全等效�? FMC1 �? mipi_phy_if_1 物理相对位置)
################################################################################
set_property IOSTANDARD LVCMOS18 [get_ports mipi_phy_if_3_clk_lp_n]
set_property IOSTANDARD LVCMOS18 [get_ports mipi_phy_if_3_clk_lp_p]
set_property IOSTANDARD LVCMOS18 [get_ports {mipi_phy_if_3_data_lp_n[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {mipi_phy_if_3_data_lp_p[*]}]
set_property IOSTANDARD LVDS [get_ports mipi_phy_if_3_clk_hs_p]
set_property IOSTANDARD LVDS [get_ports {mipi_phy_if_3_data_hs_n[*]}]
set_property IOSTANDARD LVDS [get_ports {mipi_phy_if_3_data_hs_p[*]}]
set_property PULLDOWN true  [get_ports {mipi_phy_if_3_data_lp_n[*]}]
set_property PULLDOWN true  [get_ports {mipi_phy_if_3_data_lp_p[*]}]

set_property IOSTANDARD LVCMOS18 [get_ports {csi_rstn_tri_o[3]}]
#set_property IOSTANDARD LVCMOS18 [get_ports {csi_rstn_tri_o_3[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports csi_i2c3_sda_io]
set_property IOSTANDARD LVCMOS18 [get_ports csi_i2c3_scl_io]

# MIPI LP 信号引脚映射
set_property PACKAGE_PIN AR25 [get_ports mipi_phy_if_3_clk_lp_n]
set_property PACKAGE_PIN AR24 [get_ports mipi_phy_if_3_clk_lp_p]
set_property PACKAGE_PIN AL23 [get_ports {mipi_phy_if_3_data_lp_n[0]}]
set_property PACKAGE_PIN AK23 [get_ports {mipi_phy_if_3_data_lp_p[0]}]
set_property PACKAGE_PIN AN26 [get_ports {mipi_phy_if_3_data_lp_n[1]}]
set_property PACKAGE_PIN AM26 [get_ports {mipi_phy_if_3_data_lp_p[1]}]
set_property PACKAGE_PIN AN24 [get_ports {mipi_phy_if_3_data_lp_n[2]}]
set_property PACKAGE_PIN AM24 [get_ports {mipi_phy_if_3_data_lp_p[2]}]
set_property PACKAGE_PIN BB26 [get_ports {mipi_phy_if_3_data_lp_n[3]}]
set_property PACKAGE_PIN BA26 [get_ports {mipi_phy_if_3_data_lp_p[3]}]

# MIPI HS 信号引脚映射
set_property PACKAGE_PIN AU26 [get_ports mipi_phy_if_3_clk_hs_n]
set_property PACKAGE_PIN AU25 [get_ports mipi_phy_if_3_clk_hs_p]
set_property PACKAGE_PIN AT26 [get_ports {mipi_phy_if_3_data_hs_n[0]}]
set_property PACKAGE_PIN AT25 [get_ports {mipi_phy_if_3_data_hs_p[0]}]
set_property PACKAGE_PIN BB25 [get_ports {mipi_phy_if_3_data_hs_n[1]}]
set_property PACKAGE_PIN BB24 [get_ports {mipi_phy_if_3_data_hs_p[1]}]
set_property PACKAGE_PIN BB28 [get_ports {mipi_phy_if_3_data_hs_n[2]}]
set_property PACKAGE_PIN BA28 [get_ports {mipi_phy_if_3_data_hs_p[2]}]
set_property PACKAGE_PIN AW27 [get_ports {mipi_phy_if_3_data_hs_n[3]}]
set_property PACKAGE_PIN AV27 [get_ports {mipi_phy_if_3_data_hs_p[3]}]

# I2C �? 复位控制引脚映射
set_property PACKAGE_PIN AY24 [get_ports {csi_rstn_tri_o[3]}]
#set_property PACKAGE_PIN AY24 [get_ports {csi_rstn_tri_o_3[0]}]
set_property PACKAGE_PIN AP24 [get_ports csi_i2c3_scl_io]
set_property PACKAGE_PIN AP25 [get_ports csi_i2c3_sda_io]

# 如果�?要屏蔽某�? I2C 在校准期间的干扰，同样可以添加：
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports csi_i2c2_scl_io]
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports csi_i2c3_scl_io]