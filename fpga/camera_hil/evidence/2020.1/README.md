# Real 2020.1 reconstruction and remaining signoff blockers

The user authorized only the installed 2020.1 tools; no 2020.2 installation is
required. This experiment changes neither the archived camera nor the board.
[result.json](result.json) records commands, raw-file paths/SHA256, archived-text
SHA256, source/BD/XCI audit, binary artifacts and unperformed work. Text copies
here use LF and omit trailing line padding; the unmodified raw files remain at
the recorded local paths. No bit/XSA/bin is uploaded to GitHub.

| Actual step | Result |
| --- | --- |
| Native catalog/property probe | All original IP definitions available; 32 IP up to date/included, 0 locked; 1,012 PS properties restored |
| Combined BD | Actual validate_bd_design succeeds: 32 original blocks + AHIL; original connections/addresses preserved |
| Synthesis | OOC and main synthesis succeed; main has 0 critical warnings/errors; Synthesis license acquired |
| Implementation | Placement/routing/bitgen/XSA creation complete, exit 0; Implementation license acquired |
| Clock correction | Unique original PS8 leaf sources proven; same routed DCP reanalysed, exit 0; no corrected implementation rerun |
| Timing/coverage | **Fails**: WNS +0.548 ns, WHS +0.010 ns, WPWS -1.649 ns; 14 pulse-width failures; uncovered paths below |
| DRC | **49 warnings**, 0 errors: REQP-1869 ×48, RTSTAT-10 ×1 |
| Safe packaging | **Refuses** actual 2020.1 result for failed timing, exit 1; no bin/tar/runtime package created |
| Board operations | None; no combined-profile video, HIL, STOP, watchdog or rollback tested |

The first `run01` used general Tcl `if` statements in XDC (unsupported by 2020.1)
and selected two hierarchical aliases for each clock. Its exact generated
[rebuild-executed.tcl](rebuild-executed.tcl), [log](run01-vivado.txt) and binary
hashes are preserved; it is a diagnostic artifact, not an accepted build.
The current `prepare.py` puts assertions in ordinary Tcl and reuses original
clock SOURCE_PINS, so fresh output includes that fix. That full fresh path was
not rerun through all OOC/implementation merely to repeat known blockers.

The executed [repair Tcl](repair-clock-executed.tcl) opens successful synthesis
using only the original constraints, proves each original clock has one leaf
source, then reanalyses the **same real routed DCP** with the corrected
[live clock constraints](repaired-live-clock.xdc). It does not rerun placement,
routing or bitgen in `diagnose` mode. [report_clocks](clock-diagnose-clocks.rpt)
and [clock_sources](clock-sources.txt) prove one source per PL0/PL1, at
4.982/9.965 ns (full constraint values 4.982462231192426/9.964924462384852 ns).
The [corrected-clock timing report](clock-diagnose-timing.rpt) still fails.
During the subsequent optional report_methodology, Vivado rereads the original
failed XDC stored with the checkpoint and logs its old two-source warning;
the clocks/timing/DRC files above were emitted **before** that call. Do not
interpret this diagnosis as a clean reimplementation or corrected candidate bit.

## Concrete remaining problems

1. **IDELAYCTRL reference mismatch.** The actual report requires maximum REFCLK
   period 3.333 ns; the preserved PL0-derived reference is 4.982 ns. The 14
   failing pins include
   `design_1_i/csi_4lane_raw10_3/inst/csi_rx_4lane_m0/link/gen_idctl.idctrl/gen_us.delayctrl/REFCLK`
   and tool-replicated controllers in other banks/cameras. The original BD
   connects all `csi_4lane_raw10_N/ref_clock_in` to PS PL0. Supplied
   `csi_rx_idelayctrl_gen.vhd:34–40` instantiates IDELAYCTRL on that reference;
   `csi_rx_hs_lane_phy.vhd:75` sets IDELAYE3 REFCLK_FREQUENCY to 200.0. No
   configuration was changed to make this mismatch disappear.
2. **Incomplete sensor/CSI timing constraints.** Both real timing reports show
   no_clock=2,496, unconstrained_internal_endpoints=6,036, missing input delays=24,
   missing output delays=8. Original XDC supplies pin/IO/IDELAY groups but does
   not supply a complete external MIPI clock/input timing model. Setup/hold
   slack on constrained PL0 paths is not signoff for these uncovered paths.
3. **Native URAM warnings.** 48 REQP-1869 checks concern the four VDMA S2MM
   linebuffer URAM cascade inputs (ADDR/BWE/DIN/DOUT/RDACCESS/RDB_WR buses,
   four VDMAs × two ports × six groups) that the tool says should be tied low
   for CASCADE_ORDER NONE/FIRST.
   No VDMA depth/mode, primitive tie-off or rule severity was changed here.
4. **Unroutable-load warning.** RTSTAT-10 reports 64 nets with no routable loads,
   including dbg_hub FIFO status/overflow and AXI downsizer FIFO status signals.
   The [full DRC report](clock-diagnose-drc.rpt) names the nets. They were not
   deleted or waived to satisfy a zero-DRC package check.

These are observed in this 2020.1 implementation. Without a 2020.2 comparison,
they do not prove a downgrade-specific defect or establish that the archived
source would meet signoff in 2020.2. The old fixed-hash camera bit's real video
success is a separate fact; that original bit/XSA/source stays untouched.

The smallest next design work is to evaluate a compliant **PL-local** reference
for IDELAYCTRL, with matching CSI delay/reference parameters and reset/CDC
handling while retaining PS/DDR initialization and the camera ABI. That needs
an explicit design delta and timing check, not changing PL0 to a guessed value.
Complete sensor mode/lane clock, IO delay and board skew information is also
needed to write defensible MIPI constraints. Only after those timing issues
are resolved should a narrowly proved unused-URAM tie-off/no-load cleanup be
considered, followed by one fresh native implementation and the existing
strict package gates. This needs no large tool installation. It does require
design review and separately authorized camera/board acceptance; no new MMCM
or such hardware experiment was attempted in this round.

## Reproduction

For a fresh isolated native build use
[experimental_2020_1/README.md](../../experimental_2020_1/README.md).
The exact first-run commands are in result.json. The correction diagnosis was:

```powershell
& F:/Xilinx/Vivado/2020.1/bin/vivado.bat -mode batch -nojournal -log F:/ah-camera-hil-2020.1-clock-diagnose01.log -source fpga/camera_hil/experimental_2020_1/repair_clock.tcl -tclargs F:/ah-camera-hil-2020.1-run01 F:/ah-camera-hil-2020.1-clock-diagnose01 diagnose
```

Result paths must be new. `impl` may replace `diagnose` for a separately
requested full corrected implementation; that mode was **not run here**.
Package acceptance still requires zero DRC violations, passing timing/coverage,
unique live-clock sources, preserved topology and exact bit/XSA correspondence.
The old camera/HIL standalone profiles remain the known recovery references;
switching between them is not simultaneous operation and was not done here.
