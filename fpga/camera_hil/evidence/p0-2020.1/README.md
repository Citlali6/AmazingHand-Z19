# P0 native 2020.1 repair: UNSAFE / NOT DEPLOYABLE

The [P0 request](https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/issues/17#issuecomment-6246782620)
was implemented in a new private project, `F:/ah-camera-hil-2020.1-p0-run04`.
Actual BD validation, OOC/main synthesis, placement, routing, bitgen and XSA
export complete with Vivado 2020.1, exit 0. This is a fresh implementation of
the new source/constraints, not another timing-only analysis of the old bit.
The [machine-readable result](result.json) contains raw paths/hashes, commands,
source/BD/packed-HDL audit and diagnostic artifact SHA256. No binaries or full
Sony/module manuals are uploaded to GitHub.

| Check | Actual result |
| --- | --- |
| Original archive / inherited HIL | 117 / 4 files unchanged |
| BD | Original 32 blocks + AHIL + one shared delay reference; original endpoint groups/addresses preserved |
| Physical reference | One MMCM M6/D1/O4; 14 IDELAYCTRLs on `ref_raw`, all reset by the same `reset_hold_reg[39]/Q` |
| Physical delay elements | 16 TIME-mode IDELAYE3, REFCLK_FREQUENCY 301.056 MHz, delay 20 ps, common I/O reset `[7]/Q` |
| RDY aggregation | Actual return AND trees include all 14 controllers (2 + 4 + 4 + 4); absent sensor clocks do not gate calibration reset |
| Reference pulse checks | **Fixed:** WPWS +0.012 ns, 0 failing pulse endpoints (old diagnostic: 14 failures) |
| Setup/recovery | **Fails:** WNS -1.986 ns / TNS -146.397 ns, 92 failing endpoints |
| Hold | **Fails:** WHS -0.121 ns / THS -0.126 ns, 2 failing endpoints |
| Timing coverage | Under nominal MIPI clock model: no_clock=0, unconstrained_internal_endpoints=0; **20 input / 8 output delays still missing** |
| DRC | **REQP-1869 48 -> 0**; RTSTAT-10 remains 1 warning / 60 nets, 0 errors |
| CDC | **44 Critical findings**, 64 Warning, 19 Info; includes old and new crossings below |
| Packaging | Actual CLI exit 1: `UNIFIED_PACKAGE_REFUSED: timing constraints failed`; separate CDC gate also rejects 44 Critical findings |
| Board | **Not tested:** no new PL load, SSH state changes, driver operations, SD/PS initialization or simultaneous camera/HIL acceptance |

The measured PS clock remains unchanged; M6/D1/O4 physically derives
301.055970 MHz from 200.703980 MHz. The actual tool reports quantized periods
(PL0 4.982 ns, reference about 3.321 ns), slightly faster than the exact source
constraint. Physical inspection is in [physical-reference.txt](physical-reference.txt),
with the [executed inspection Tcl](review-impl-executed.tcl). It changes no netlist
or timing constraints. Simulation separately verifies reset ordering, >106 ns
I/O-to-controller separation, all-four-RDY requirement, external reset and injected
lock-loss assertion; it is not hardware BISC acceptance.

## Remaining violations and minimum next work

The old WNS +0.548 ns excluded thousands of undefined-clock endpoints. The new
negative WNS includes nominal sensor-clock and reset crossings, so these values
must not be presented as a simple performance regression. See the complete
[timing](timing_impl.rpt), [coverage](coverage_details.rpt), [CDC](cdc_impl.rpt)
and categorized [violating paths](violating-paths.json).

1. **Original clock detector and FIFO CDC.** Worst recovery -1.986 ns is CSI2
   `clkdet/clk_fail_count_reg[5]/C -> count_value_reg[0]/CLR` (PL0 -> byte clock).
   Setup -1.788 ns is CSI0 byte-clock output -> `clkdet/ext_clk_lat_reg/D`;
   `fifo_ready_reg -> fifo_ready_maxis_reg/D` also fails (single-stage crossing).
   Minimum repair: a reviewed clock-presence/reset-release synchronizer and
   genuine two-stage ready transfer, with focused fault/clock-stop tests.
2. **New ready/reset crossings are not signed off.** For example,
   `delay_reference/ready_release_reg[2]/C -> CSI0 ready_byte_reg[0]/CLR`
   fails recovery by -1.950 ns; application counters and PHY reset synchronizers
   also appear in CDC/recovery reports. Shared bank-safe primitive sequencing
   is implemented, but adding ASYNC_REG alone does not close reset-domain CDC.
   Minimum repair: evaluate XPM asynchronous-reset structures, combine reset
   causes deliberately, release application logic only in its byte domain, and
   justify any narrowly scoped first-stage exception. No broad clock groups or
   false paths were added to make these findings disappear.
3. **SERDES capture hold.** CSI0 `d0phy/gen_us.ideser/RX_DIV4_CLK_Q ->
   gen_bytealign[0].ba/curr_byte_reg[5]/D` is -0.121 ns; CSI3 corresponding path
   is -0.005 ns. These are ISERDES internal divide-clock to external byte-clock
   capture paths, not the IDELAY reference mismatch. Review component-mode
   clock alignment/skew/placement against UG571 before a targeted implementation;
   do not waive the data paths or change FIFO mode without proof.
4. **External I/O bounds remain incomplete.** The 171.875 MHz model follows
   existing register values and the local 25 MHz FL0214 REV1.0 / 2018-03-14
   schematic and Sony software-reference formulas. It is not a scope measurement.
   Missing delays cover 16 HS data inputs plus four PL AXI-IIC inputs; outputs
   are four IIC and four camera-reset pins. Minimum inputs for signoff are the
   actual module/oscillator part and ppm/jitter bounds, sensor output timing at
   this mode, bridge timing and PCB/FMC trace/skew bounds, and a defensible IIC/
   reset external interface model. Local MC20901 data alone does not bound the
   whole link. No further wiring is needed for the present offline deliverable.
5. **Protected vendor no-load outputs.** RTSTAT-10 now lists 60 nets (old 64),
   but the hook actually removed **0**. Do not credit this count change to
   cleanup. DCP attempts exposed DONT_TOUCH and security-protected debug/downsizer
   internals; these were retained. A vendor-supported fix or an explicit future
   exception decision is needed; this PR does not waive the rule or change the
   zero-DRC deployment gate.

Planning estimate, not a completed test: 2-4 hours for focused CDC/reset changes
and tests, 2-4 hours for component clock/hold review plus one targeted build;
external I/O completion depends on the missing board/mode bounds. No entire
camera-system rewrite or Vivado 2020.2 installation is a prerequisite.

## Reproduction and evidence boundaries

Use [the repair command](../../experimental_2020_1/README.md), with a new output
directory and `--repair-csi`. This round used `p0-run04`; the earlier per-CSI-MMCM
`p0-run01` was intentionally stopped after the shared-bank reset review. `run02`
stopped during exact source preparation; `run03` was prepared but never invoked.
Their history is retained in result.json. None is a candidate firmware artifact.

The [executed rebuild Tcl](rebuild-executed.tcl), [Vivado log](vivado.txt),
[netlist hook](netlist-hook-executed.tcl), [hook result](netlist-repair.txt),
[DRC](drc_impl.rpt), [clocks](clocks_impl.rpt), and exact source reconstruction
ledger are archived here. LF copies strip trailing padding/blank EOF lines;
result.json records both raw-local and normalized-file SHA256. Original raw
files and diagnostic bit/XSA remain at their recorded absolute local paths.
Original camera and standalone HIL recovery profiles remain unchanged.

STOP/watchdog/session binding and the existing zero timing/DRC/coverage gates
remain in force. The repair profile additionally requires a genuine CDC report
with zero Critical findings. No bin/tar/deployment package was created, and no
new firmware was loaded. Board calibration, video, HIL/STOP/watchdog/rollback
and same-bit dual-function testing are all **not performed**.
