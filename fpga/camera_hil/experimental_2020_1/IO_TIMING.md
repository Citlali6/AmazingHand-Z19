# Remaining external I/O timing inputs

The full design has 20 inputs and 8 outputs without external delay models.
These are explicit signoff blockers; nominal clocks do not supply these bounds.
The exact current `coverage_details.rpt` is the authority for the final port list.
No guessed delay, asynchronous clock group or blanket false path is applied.

| Input port | Required minimum evidence before constraining |
| --- | --- |
| `mipi_phy_if_0_data_hs_p[0]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_0_data_hs_p[1]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_0_data_hs_p[2]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_0_data_hs_p[3]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_1_data_hs_p[0]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_1_data_hs_p[1]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_1_data_hs_p[2]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_1_data_hs_p[3]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_2_data_hs_p[0]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_2_data_hs_p[1]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_2_data_hs_p[2]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_2_data_hs_p[3]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_3_data_hs_p[0]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_3_data_hs_p[1]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_3_data_hs_p[2]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `mipi_phy_if_3_data_hs_p[3]` | Sensor DDR data-to-forwarded-clock min/max for both edges; bridge channel relative delay/jitter; board/FMC/cable lane-to-clock min/max; oscillator tolerance and duty-cycle bounds. |
| `csi_i2c2_scl_io` | Actual bus rate/mode, external device setup/hold and clock stretch, pull-up/load rise/fall and board delay; bidirectional open-drain timing model. |
| `csi_i2c2_sda_io` | Actual bus rate/mode, external device setup/hold and clock stretch, pull-up/load rise/fall and board delay; bidirectional open-drain timing model. |
| `csi_i2c3_scl_io` | Actual bus rate/mode, external device setup/hold and clock stretch, pull-up/load rise/fall and board delay; bidirectional open-drain timing model. |
| `csi_i2c3_sda_io` | Actual bus rate/mode, external device setup/hold and clock stretch, pull-up/load rise/fall and board delay; bidirectional open-drain timing model. |

| Output port | Required minimum evidence before constraining |
| --- | --- |
| `csi_i2c2_scl_io` | Actual external device receive setup/hold, pull-up/load rise/fall, bus clock relationship and board min/max delay. |
| `csi_i2c2_sda_io` | Actual external device receive setup/hold, pull-up/load rise/fall, bus clock relationship and board min/max delay. |
| `csi_i2c3_scl_io` | Actual external device receive setup/hold, pull-up/load rise/fall, bus clock relationship and board min/max delay. |
| `csi_i2c3_sda_io` | Actual external device receive setup/hold, pull-up/load rise/fall, bus clock relationship and board min/max delay. |
| `csi_rstn_tri_o[0]` | Sensor reset pulse/release requirements, relation to MCLK/power stability, board propagation and receiving setup/hold (or a specifically reviewed asynchronous-control model). |
| `csi_rstn_tri_o[1]` | Sensor reset pulse/release requirements, relation to MCLK/power stability, board propagation and receiving setup/hold (or a specifically reviewed asynchronous-control model). |
| `csi_rstn_tri_o[2]` | Sensor reset pulse/release requirements, relation to MCLK/power stability, board propagation and receiving setup/hold (or a specifically reviewed asynchronous-control model). |
| `csi_rstn_tri_o[3]` | Sensor reset pulse/release requirements, relation to MCLK/power stability, board propagation and receiving setup/hold (or a specifically reviewed asynchronous-control model). |

The negative pins are differential partners; they are not extra unconstrained
logical data ports in Vivado's report. MIPI LP inputs in the archived wrapper are
not timed data consumers in the retained RX implementation and are not added to
the reported list as invented failures.

Known nominal source, not complete signoff:

- Local FL0214 manual REV1.0 p6 and `CD/原理图/fl0214_2018-3-14.pdf` p4 show
  X1 OSC25MHz -> U12 5PB1102PGGI -> sensor MCLK. The schematic does not identify
  a crystal tolerance BOM or PCB flight-time extrema.
- Sony `IMX214_Software_Reference_Manual_0.0.6应用手册.pdf` pp47-49 and the
  unchanged sensor register table yield 25/8*110/2 = 171.875MHz nominal HS clock.
  This is not a frequency measurement or a full sensor output-skew guarantee.
- Local `CD/芯片手册/MC20901-V1_08.pdf`, Table4 p8: bridge propagation
  300-900ps, channel-skew entry50ps has a 3-sigma mismatch qualifier, deterministic
  jitter30ps and generated random jitter0.7psrms. These are bridge contributions,
  not guaranteed complete sensor-to-FPGA setup/hold limits.
- Missing minimum inputs are the exact physical board/oscillator revision and
  tolerance, sensor transmit DDR edge/skew/jitter limits for this register profile,
  and complete bridge/cable/FMC/PCB relative-delay extrema. IIC/reset constraints
  need their separate external interface requirements above.

The local vendor manuals are read-only references and are not redistributed.
Obtaining these bounds and implementing reviewed edge-specific constraints is a
separate engineering task; it does not require rebuilding the Linux camera stack.
No board probing or configuration changes were performed in this task.
