//Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
//Date        : Tue May 12 22:39:06 2026
//Host        : mang running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (csi_i2c0_scl_io,
    csi_i2c0_sda_io,
    csi_i2c1_scl_io,
    csi_i2c1_sda_io,
    csi_i2c2_scl_io,
    csi_i2c2_sda_io,
    csi_i2c3_scl_io,
    csi_i2c3_sda_io,
    csi_rstn_tri_o,
    mipi_phy_if_0_clk_hs_n,
    mipi_phy_if_0_clk_hs_p,
    mipi_phy_if_0_clk_lp_n,
    mipi_phy_if_0_clk_lp_p,
    mipi_phy_if_0_data_hs_n,
    mipi_phy_if_0_data_hs_p,
    mipi_phy_if_0_data_lp_n,
    mipi_phy_if_0_data_lp_p,
    mipi_phy_if_1_clk_hs_n,
    mipi_phy_if_1_clk_hs_p,
    mipi_phy_if_1_clk_lp_n,
    mipi_phy_if_1_clk_lp_p,
    mipi_phy_if_1_data_hs_n,
    mipi_phy_if_1_data_hs_p,
    mipi_phy_if_1_data_lp_n,
    mipi_phy_if_1_data_lp_p,
    mipi_phy_if_2_clk_hs_n,
    mipi_phy_if_2_clk_hs_p,
    mipi_phy_if_2_clk_lp_n,
    mipi_phy_if_2_clk_lp_p,
    mipi_phy_if_2_data_hs_n,
    mipi_phy_if_2_data_hs_p,
    mipi_phy_if_2_data_lp_n,
    mipi_phy_if_2_data_lp_p,
    mipi_phy_if_3_clk_hs_n,
    mipi_phy_if_3_clk_hs_p,
    mipi_phy_if_3_clk_lp_n,
    mipi_phy_if_3_clk_lp_p,
    mipi_phy_if_3_data_hs_n,
    mipi_phy_if_3_data_hs_p,
    mipi_phy_if_3_data_lp_n,
    mipi_phy_if_3_data_lp_p);
  inout csi_i2c0_scl_io;
  inout csi_i2c0_sda_io;
  inout csi_i2c1_scl_io;
  inout csi_i2c1_sda_io;
  inout csi_i2c2_scl_io;
  inout csi_i2c2_sda_io;
  inout csi_i2c3_scl_io;
  inout csi_i2c3_sda_io;
  output [3:0]csi_rstn_tri_o;
  input mipi_phy_if_0_clk_hs_n;
  input mipi_phy_if_0_clk_hs_p;
  input mipi_phy_if_0_clk_lp_n;
  input mipi_phy_if_0_clk_lp_p;
  input [3:0]mipi_phy_if_0_data_hs_n;
  input [3:0]mipi_phy_if_0_data_hs_p;
  input [3:0]mipi_phy_if_0_data_lp_n;
  input [3:0]mipi_phy_if_0_data_lp_p;
  input mipi_phy_if_1_clk_hs_n;
  input mipi_phy_if_1_clk_hs_p;
  input mipi_phy_if_1_clk_lp_n;
  input mipi_phy_if_1_clk_lp_p;
  input [3:0]mipi_phy_if_1_data_hs_n;
  input [3:0]mipi_phy_if_1_data_hs_p;
  input [3:0]mipi_phy_if_1_data_lp_n;
  input [3:0]mipi_phy_if_1_data_lp_p;
  input mipi_phy_if_2_clk_hs_n;
  input mipi_phy_if_2_clk_hs_p;
  input mipi_phy_if_2_clk_lp_n;
  input mipi_phy_if_2_clk_lp_p;
  input [3:0]mipi_phy_if_2_data_hs_n;
  input [3:0]mipi_phy_if_2_data_hs_p;
  input [3:0]mipi_phy_if_2_data_lp_n;
  input [3:0]mipi_phy_if_2_data_lp_p;
  input mipi_phy_if_3_clk_hs_n;
  input mipi_phy_if_3_clk_hs_p;
  input mipi_phy_if_3_clk_lp_n;
  input mipi_phy_if_3_clk_lp_p;
  input [3:0]mipi_phy_if_3_data_hs_n;
  input [3:0]mipi_phy_if_3_data_hs_p;
  input [3:0]mipi_phy_if_3_data_lp_n;
  input [3:0]mipi_phy_if_3_data_lp_p;

  wire csi_i2c0_scl_i;
  wire csi_i2c0_scl_io;
  wire csi_i2c0_scl_o;
  wire csi_i2c0_scl_t;
  wire csi_i2c0_sda_i;
  wire csi_i2c0_sda_io;
  wire csi_i2c0_sda_o;
  wire csi_i2c0_sda_t;
  wire csi_i2c1_scl_i;
  wire csi_i2c1_scl_io;
  wire csi_i2c1_scl_o;
  wire csi_i2c1_scl_t;
  wire csi_i2c1_sda_i;
  wire csi_i2c1_sda_io;
  wire csi_i2c1_sda_o;
  wire csi_i2c1_sda_t;
  wire csi_i2c2_scl_i;
  wire csi_i2c2_scl_io;
  wire csi_i2c2_scl_o;
  wire csi_i2c2_scl_t;
  wire csi_i2c2_sda_i;
  wire csi_i2c2_sda_io;
  wire csi_i2c2_sda_o;
  wire csi_i2c2_sda_t;
  wire csi_i2c3_scl_i;
  wire csi_i2c3_scl_io;
  wire csi_i2c3_scl_o;
  wire csi_i2c3_scl_t;
  wire csi_i2c3_sda_i;
  wire csi_i2c3_sda_io;
  wire csi_i2c3_sda_o;
  wire csi_i2c3_sda_t;
  wire [3:0]csi_rstn_tri_o;
  wire mipi_phy_if_0_clk_hs_n;
  wire mipi_phy_if_0_clk_hs_p;
  wire mipi_phy_if_0_clk_lp_n;
  wire mipi_phy_if_0_clk_lp_p;
  wire [3:0]mipi_phy_if_0_data_hs_n;
  wire [3:0]mipi_phy_if_0_data_hs_p;
  wire [3:0]mipi_phy_if_0_data_lp_n;
  wire [3:0]mipi_phy_if_0_data_lp_p;
  wire mipi_phy_if_1_clk_hs_n;
  wire mipi_phy_if_1_clk_hs_p;
  wire mipi_phy_if_1_clk_lp_n;
  wire mipi_phy_if_1_clk_lp_p;
  wire [3:0]mipi_phy_if_1_data_hs_n;
  wire [3:0]mipi_phy_if_1_data_hs_p;
  wire [3:0]mipi_phy_if_1_data_lp_n;
  wire [3:0]mipi_phy_if_1_data_lp_p;
  wire mipi_phy_if_2_clk_hs_n;
  wire mipi_phy_if_2_clk_hs_p;
  wire mipi_phy_if_2_clk_lp_n;
  wire mipi_phy_if_2_clk_lp_p;
  wire [3:0]mipi_phy_if_2_data_hs_n;
  wire [3:0]mipi_phy_if_2_data_hs_p;
  wire [3:0]mipi_phy_if_2_data_lp_n;
  wire [3:0]mipi_phy_if_2_data_lp_p;
  wire mipi_phy_if_3_clk_hs_n;
  wire mipi_phy_if_3_clk_hs_p;
  wire mipi_phy_if_3_clk_lp_n;
  wire mipi_phy_if_3_clk_lp_p;
  wire [3:0]mipi_phy_if_3_data_hs_n;
  wire [3:0]mipi_phy_if_3_data_hs_p;
  wire [3:0]mipi_phy_if_3_data_lp_n;
  wire [3:0]mipi_phy_if_3_data_lp_p;

  IOBUF csi_i2c0_scl_iobuf
       (.I(csi_i2c0_scl_o),
        .IO(csi_i2c0_scl_io),
        .O(csi_i2c0_scl_i),
        .T(csi_i2c0_scl_t));
  IOBUF csi_i2c0_sda_iobuf
       (.I(csi_i2c0_sda_o),
        .IO(csi_i2c0_sda_io),
        .O(csi_i2c0_sda_i),
        .T(csi_i2c0_sda_t));
  IOBUF csi_i2c1_scl_iobuf
       (.I(csi_i2c1_scl_o),
        .IO(csi_i2c1_scl_io),
        .O(csi_i2c1_scl_i),
        .T(csi_i2c1_scl_t));
  IOBUF csi_i2c1_sda_iobuf
       (.I(csi_i2c1_sda_o),
        .IO(csi_i2c1_sda_io),
        .O(csi_i2c1_sda_i),
        .T(csi_i2c1_sda_t));
  IOBUF csi_i2c2_scl_iobuf
       (.I(csi_i2c2_scl_o),
        .IO(csi_i2c2_scl_io),
        .O(csi_i2c2_scl_i),
        .T(csi_i2c2_scl_t));
  IOBUF csi_i2c2_sda_iobuf
       (.I(csi_i2c2_sda_o),
        .IO(csi_i2c2_sda_io),
        .O(csi_i2c2_sda_i),
        .T(csi_i2c2_sda_t));
  IOBUF csi_i2c3_scl_iobuf
       (.I(csi_i2c3_scl_o),
        .IO(csi_i2c3_scl_io),
        .O(csi_i2c3_scl_i),
        .T(csi_i2c3_scl_t));
  IOBUF csi_i2c3_sda_iobuf
       (.I(csi_i2c3_sda_o),
        .IO(csi_i2c3_sda_io),
        .O(csi_i2c3_sda_i),
        .T(csi_i2c3_sda_t));
  design_1 design_1_i
       (.csi_i2c0_scl_i(csi_i2c0_scl_i),
        .csi_i2c0_scl_o(csi_i2c0_scl_o),
        .csi_i2c0_scl_t(csi_i2c0_scl_t),
        .csi_i2c0_sda_i(csi_i2c0_sda_i),
        .csi_i2c0_sda_o(csi_i2c0_sda_o),
        .csi_i2c0_sda_t(csi_i2c0_sda_t),
        .csi_i2c1_scl_i(csi_i2c1_scl_i),
        .csi_i2c1_scl_o(csi_i2c1_scl_o),
        .csi_i2c1_scl_t(csi_i2c1_scl_t),
        .csi_i2c1_sda_i(csi_i2c1_sda_i),
        .csi_i2c1_sda_o(csi_i2c1_sda_o),
        .csi_i2c1_sda_t(csi_i2c1_sda_t),
        .csi_i2c2_scl_i(csi_i2c2_scl_i),
        .csi_i2c2_scl_o(csi_i2c2_scl_o),
        .csi_i2c2_scl_t(csi_i2c2_scl_t),
        .csi_i2c2_sda_i(csi_i2c2_sda_i),
        .csi_i2c2_sda_o(csi_i2c2_sda_o),
        .csi_i2c2_sda_t(csi_i2c2_sda_t),
        .csi_i2c3_scl_i(csi_i2c3_scl_i),
        .csi_i2c3_scl_o(csi_i2c3_scl_o),
        .csi_i2c3_scl_t(csi_i2c3_scl_t),
        .csi_i2c3_sda_i(csi_i2c3_sda_i),
        .csi_i2c3_sda_o(csi_i2c3_sda_o),
        .csi_i2c3_sda_t(csi_i2c3_sda_t),
        .csi_rstn_tri_o(csi_rstn_tri_o),
        .mipi_phy_if_0_clk_hs_n(mipi_phy_if_0_clk_hs_n),
        .mipi_phy_if_0_clk_hs_p(mipi_phy_if_0_clk_hs_p),
        .mipi_phy_if_0_clk_lp_n(mipi_phy_if_0_clk_lp_n),
        .mipi_phy_if_0_clk_lp_p(mipi_phy_if_0_clk_lp_p),
        .mipi_phy_if_0_data_hs_n(mipi_phy_if_0_data_hs_n),
        .mipi_phy_if_0_data_hs_p(mipi_phy_if_0_data_hs_p),
        .mipi_phy_if_0_data_lp_n(mipi_phy_if_0_data_lp_n),
        .mipi_phy_if_0_data_lp_p(mipi_phy_if_0_data_lp_p),
        .mipi_phy_if_1_clk_hs_n(mipi_phy_if_1_clk_hs_n),
        .mipi_phy_if_1_clk_hs_p(mipi_phy_if_1_clk_hs_p),
        .mipi_phy_if_1_clk_lp_n(mipi_phy_if_1_clk_lp_n),
        .mipi_phy_if_1_clk_lp_p(mipi_phy_if_1_clk_lp_p),
        .mipi_phy_if_1_data_hs_n(mipi_phy_if_1_data_hs_n),
        .mipi_phy_if_1_data_hs_p(mipi_phy_if_1_data_hs_p),
        .mipi_phy_if_1_data_lp_n(mipi_phy_if_1_data_lp_n),
        .mipi_phy_if_1_data_lp_p(mipi_phy_if_1_data_lp_p),
        .mipi_phy_if_2_clk_hs_n(mipi_phy_if_2_clk_hs_n),
        .mipi_phy_if_2_clk_hs_p(mipi_phy_if_2_clk_hs_p),
        .mipi_phy_if_2_clk_lp_n(mipi_phy_if_2_clk_lp_n),
        .mipi_phy_if_2_clk_lp_p(mipi_phy_if_2_clk_lp_p),
        .mipi_phy_if_2_data_hs_n(mipi_phy_if_2_data_hs_n),
        .mipi_phy_if_2_data_hs_p(mipi_phy_if_2_data_hs_p),
        .mipi_phy_if_2_data_lp_n(mipi_phy_if_2_data_lp_n),
        .mipi_phy_if_2_data_lp_p(mipi_phy_if_2_data_lp_p),
        .mipi_phy_if_3_clk_hs_n(mipi_phy_if_3_clk_hs_n),
        .mipi_phy_if_3_clk_hs_p(mipi_phy_if_3_clk_hs_p),
        .mipi_phy_if_3_clk_lp_n(mipi_phy_if_3_clk_lp_n),
        .mipi_phy_if_3_clk_lp_p(mipi_phy_if_3_clk_lp_p),
        .mipi_phy_if_3_data_hs_n(mipi_phy_if_3_data_hs_n),
        .mipi_phy_if_3_data_hs_p(mipi_phy_if_3_data_hs_p),
        .mipi_phy_if_3_data_lp_n(mipi_phy_if_3_data_lp_n),
        .mipi_phy_if_3_data_lp_p(mipi_phy_if_3_data_lp_p));
endmodule
