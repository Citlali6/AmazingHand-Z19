# Structural P0 result: modeled timing and CDC close; NOT DEPLOYABLE

One fresh Vivado2020.1 full reconstruction, OOC/main synthesis, placement,
routing, bit generation and XSA export actually completed (exit0, 2026-10-18
17:13:29 Asia/Shanghai). This is new RTL and a new bit, not old-DCP reanalysis.
The original117 camera files and4 inherited HIL files remain unchanged.
[Machine-readable facts, commands and hashes](result.json) and
[raw/normalized evidence map](all-evidence.json) accompany the actual logs.

| Check | Previous P0 run04 | Fresh CDC run01 |
| --- | --- | --- |
| Setup/recovery WNS / failing endpoints | -1.986ns /92 | +0.574ns /0 |
| Hold WHS / failing endpoints | -0.121ns /2 | +0.010ns /0 |
| Pulse WPWS / failing endpoints | +0.012ns /0 | +0.012ns /0 |
| CDC Critical / Warning |44 /64 |0 /0 |
| CDC Info |19 |39 (CDC3=25, CDC9=14) |
| Unclocked / internal unconstrained |0 /0 |0 /0 |
| Missing external input/output delays |20 /8 |20 /8, still blocking |
| XPM bus skew |not separately gated |12 reported, minimum+4.079ns; gatePASS |
| DRC |REQP0, RTSTAT1/60nets |REQP0, RTSTAT1/60nets; still blocking |
| Strict packaging |timing refusal |actual exit1:DRC must have zero violations |
| Board camera+HIL |not tested |not tested; no load authorized |

“All user specified timing constraints are met” covers **modeled paths**.
It does not supply external sensor/IIC/reset timing guarantees. Vivado CDC also
skips unconstrained input ports; zero Critical is a tool result within this
clock/constraint model, not complete camera electrical or functional acceptance.

## What changed and what the real implementation proves

- A source byte-domain heartbeat FF crosses3 XPM stages into PL0; registered
  missing-clock state returns through XPM asynchronous assertion/synchronous
  byte release. The approximately1us timeout detects stop-high and stop-low.
- Each RDY is separately synchronized to reference, then qualification is
  registered before a single byte-domain reset transfer. Application waits
  64 byte cycles. Full local link reset also flushes the original FIFO.
- FIFO write-ready originates in a byte-domain register and crosses3 stages;
  actual wr/rd busy, full/empty and stream reset gate transfers. AXIS valid is
  independent of ready. Original4096x42 auto/FWFT parameters are unchanged.
- Divider clear releases through a real undivided-HS-clock XPM reset. All16
  actual routed ISERDESE3s use identical CLK/CLK_B nets and local inversion
  `1'b1`; four divider CLR drivers are XPM final-stage FFs. The actual targeted
  SERDES→bytealign hold report starts at+0.357ns. No hold exception or arbitrary
  input/data delay was added. [Physical facts](physical-cdc.txt),
  [SERDES hold paths](serdes-hold.rpt), [reference/reset audit](physical-reference.txt).
- The shared301.055970MHz MMCM reference,14CTRL/16DELAY common calibration
  sequence and1424 narrowly checked URAM ties are retained. No PS/DDR/address/
  driver ABI/SD change. Original32BD blocks+AHIL+sharedreference =34blocks.
- Exact private patch v3 covers6HDL+component.xml, audited against the untouched
  archive and actual ipshared bytes. No broad false paths/clock groups, waiver,
  DRC severity reduction, IP mode/depth change or signoff gate relaxation.

The first physical script incorrectly compared the returned literal `1'b1`
against decimal1. The failed script/log and an independent full16-lane net/
driver dump are retained; accepting that exact literal fixed the **audit**, not
the design. [Attempts and boundaries](attempts.json).

## CDC classes: inherited and new paths counted separately

| Actual report class | Previous | New |
| --- | --- | --- |
| CDC1 unknown one-bit |8 |0 |
| CDC7 unknown async reset |8 |0 |
| CDC10 combinational input to synchronizer |16 |0 |
| CDC12 multiclock fan-in |8 |0 |
| CDC13 non-FD clock-div clear path |4 |0 |
| CDC15 clock-enable warning |64 |0 |

Of44 prior Critical findings, inherited clockdet/FIFO-ready/divider reset each
accounted for4; the newer reference/application/PHY reset structure accounted
for32. The64 prior Warning findings split8clockdet/56new ready-counter reset.
[Exact prior source/destination classification](prior-cdc-categories.json),
[final whole-design report](cdc_impl.rpt), [prior whole-design report](../p0-2020.1/cdc_impl.rpt).
The local one-CSI synthesis initially exposed2 new CDC11 findings from duplicate
reset transfers; those were structurally removed before the single full build.
Local0Critical was never presented as whole-design signoff.

## Focused tests and limits

[Reproducible XSim commands and transcript](fault-tests.txt) actually pass reset,
MMCM loss/relock, RDY delay/loss, high/low stopped byte clock/restart, qualification,
busy/full/empty/backpressure/stream reset, and actual vendor-FIFO stale-data flush
with independent over/underflow checks. The old HIL100-line bench passes STOP,
watchdog and disconnect/replay checks; its bytes match origin/main, and inherited
RTL is unchanged.9safety/package-rejection checks and1private-patch tamper test pass.

The additional SIM_ASSERT_CHK1 run is **not clean**: S4/S5/S6/S7 are preserved in
[fault diagnostic](fifo-extra-vendor-assertions-not-clean.txt). S5 checks cross-domain
pointer equality in one cycle despite its sleep message; S4 is not declared a
proven vendor bug. The final test uses the original production default0 and
independent busy/empty/flush checks; this does not imply those extra vendor
assertions passed. The earlier wrong-profile harness timeout is retained too.

Normal noncontinuous HS/frame gaps can trigger the detector as well. Flush under
backpressure may discard pending tail pixels. Four-word FIFO tests do not prove
TUSER/TLAST, complete-frame integrity or VDMA recovery. This is a remaining
functional acceptance blocker, not a claim of unchanged live camera behavior.

## Remaining minimum work

1. Complete the20input/8output edge-specific external models using the
   [per-port requirements](../../experimental_2020_1/IO_TIMING.md): exact board/
   oscillator tolerance, sensor output skew/jitter and bridge/cable/FMC/PCB extrema,
   plus IIC/reset external requirements. Nominal clock derivation is documented;
   no data is invented. After qualified data is available, budget roughly1–2
   engineering days for constraints/review; supplier-data lead time is unknown.
2. Resolve RTSTAT-10 through vendor-supported treatment of protected debug/AXI
   internals, with proof of no functional effect. This run removes0unused nets.
   No supported treatment was established, so the zero-DRC gate remains closed.
   A focused vendor/reproducer investigation is required; no credible completion
   estimate is available before that answer.
3. [Methodology](methodology_impl.rpt) still reports64findings: LUTAR1=18,
   TIMING18=40, XDCC1/7=2each, CLKC30/56=1each. Eight LUTAR alerts concern the
   private CSI qualification/reset combiners; the rest include retained vendor/
   HIL/reference logic. Zero CDC does not clear these async-reset glitch alerts.
   Review actual assertion/deassertion logic and pulse behavior, with focused
   reset tests/physical proof; no warning was waived in this delivery.
4. Prove normal-gap/full-frame/backpressure/reset recovery in focused protocol
   verification, then separately obtain authorization for real camera+HIL in
   this same bit. Allow at least one focused engineering iteration; duration
   depends on the findings. No hardware action, dependency install or Issue20
   end-to-end integration occurred here.

## Reproduce and local diagnostic artifacts

```powershell
python fpga/camera_hil/experimental_2020_1/run_local_tests.py --output F:/ah-camera-hil-faults-new
python fpga/camera_hil/experimental_2020_1/prepare.py --output F:/ah-camera-hil-cdc-new --stage impl --repair-csi
& F:/Xilinx/Vivado/2020.1/bin/vivado.bat -mode batch -nojournal -log F:/ah-camera-hil-cdc-new/vivado.log -source F:/ah-camera-hil-cdc-new/rebuild.tcl
python fpga/camera_hil/audit.py --build F:/ah-camera-hil-cdc-new
```

Both binaries stay local and are **not uploaded to GitHub, not deployable**:

- `F:/ah-camera-hil-cdc-run01/vivado/mipi_dp.runs/impl_1/design_1_wrapper.bit`,
  12134116B, SHA256`3103b4f875fe3019a83274f440b8a7dd71e88754ce41ecb5e7a3fe2228688e6a`.
- `F:/ah-camera-hil-cdc-run01/camera_hil.xsa`,2330915B,
  SHA256`f518bf32fa55aa6b64322393aead38023bc977640a864028b9b52791cd117f81`.
  Its unique embedded camera_hil.bit equals the external bit byte-for-byte.

The strict packager created no bin, tar or deployment directory. No new XSA
psu_init/FSBL/DDR initialization was executed. Original standalone rollback
profiles, Linux, driver and SD are untouched. No new board load/test was run.
