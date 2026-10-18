# Camera + AHIL unified PL (Issue #17)

**2026-10-18: source implementation delivered; hardware build blocked by missing
Vivado 2020.2.** This host has 2020.1, which actually exits 1 at the preserved
version guard. No unified BD has been generated/validated by Vivado; no new
bit/XSA/bin, synthesis, timing, DRC or simultaneous camera/HIL board test exists.
The user confirmed that no 2020.2 installation is available. Do not downgrade
the camera project or substitute the previously tested HIL-only bit.

## Source and topology

Base: `main` `ee52f09ae78d7163067d627eeae0d627ea92855c`.
The archived camera project, validated bit/XSA, driver, SD, and original source
are untouched. `build.tcl` invokes the original guarded camera creation script
into a new output directory, then modifies that **copy** through Vivado BD APIs:

- Keep the complete four-camera CSI/Bayer/Gamma/VDMA→SmartConnect→HP1 path,
  camera external ports/XDC, PS properties, clocks, resets and all 11 addresses.
- Keep HPM0_FPD at 128 bits. Extend its existing `ps8_0_axi_periph` from 11 to
  12 master interfaces; connect new M11 to `hand_hil_shell/s_axi` (AXI4-Lite).
  The original interconnect performs protocol/width conversion.
- Connect AHIL and M11 to the existing PL0 clock and peripheral reset net.
  Add only 4 KiB at `0xA1000000`; the original 11 × 64 KiB control ranges are
  `0xA0000000` through `0xA00AFFFF`. Camera 0 retains VDMA `0xA0060000`, Gamma
  `0xA0040000` and reset GPIO `0xA0080000`.
- AHIL uses the previously measured **200703980 Hz** clock for its independent
  500 ms watchdog/100 Hz FSM. Implementation constraints use 4.98246 ns PL0 and
  9.96492 ns PL1 (preserved 2:1 reference profile); deployment verifies both
  live clocks. No PS clock register or FSBL changes are performed.

`rtl/{grasp_fsm.sv,hand_hil_axi.sv,hand_hil_shell.v}` and `ps/hil_server.py`
are exact selective copies of unmerged [PR #13](https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/pull/13)
at `caa84a5ddb541cd60ebd2e07869b83671ca8a1e2`; original paths and byte hashes
are in `provenance.json`. The fixed FSM is local to this design; the baseline
`fpga/rtl/grasp_fsm.sv` is unchanged. PR #13's standalone project, deployment
loader and old evidence are not imported. [PR #12](https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/pull/12)
at `583abe105eb2035f3f272556229f66b1530b742f` supplies the separate PC
`amazinghand-hil/1` MuJoCo client; it is not in main or this PR. PR #15 is not
imported. Interface v0.3 remains a draft. There are no physical servo pins.

## Rebuild with the matching tool

Use a new absolute destination. This command performs no board access:

```powershell
& 'PATH-TO-VIVADO-2020.2/bin/vivado.bat' -mode batch -nojournal -nolog -source fpga/camera_hil/build.tcl -tclargs F:/ah-camera-hil-build-new impl
python fpga/camera_hil/audit.py --build F:/ah-camera-hil-build-new
```

`generate` or `synth` may replace `impl` for staged diagnosis. Expected completed
outputs: `source/.../design_1.bd`, `camera_hil_bd.tcl`, the private
`vivado/mipi_dp.xpr`, `vivado/mipi_dp.runs/impl_1/design_1_wrapper.bit`,
`camera_hil.xsa`, and IP/utilization/timing/DRC/methodology reports.
Generation is not implementation acceptance. Locked IP causes refusal; do not
run `upgrade_ip`. The original camera was `2020.2_AR75986`; any remaining
patch/IP compatibility problem must be resolved in that matching environment.

The supplied ALINX CSI and Digilent Bayer/Gamma repositories contain all
35 component-declared file references, with no missing files and no protected
HDL blocks found. They keep their original vendor notices. No new third-party
IP is introduced. **2020.2 IP lock state, device license and synthesis rights
remain unverified** until the matching tool can open the project; the bundled
source/IP hashes alone do not prove a working license or successful rebuild.

`audit.py` checks 117 camera archive hashes and the four inherited hashes. With
`--build`, it additionally checks copied camera HDL/XDC/IP source hashes, every
original top-level BD component/parameter/connection, external interface, camera
address segment, DMA address map, and the new AHIL clock/reset/address connection.

Only a completed, audited implementation may be packaged:

```powershell
python fpga/camera_hil/package_linux.py --build F:/ah-camera-hil-build-new --output F:/amazinghand-camera-hil-new --bootgen F:/Xilinx/Vitis/2020.1/bin/bootgen.bat
```

The packager requires 2020.2 reports, passing timing at both live periods,
zero DRC violations and zero reported unconstrained/internal/clock/partial IO
checks, plus an XSA whose embedded bit exactly matches the output bit. It
converts copies of both bits with Bootgen and verifies the original camera bin
against `e25e9bc7fd4c2008c7a198a91bc4937716b333259d08da7ed777d8ffe9b3384b`.
It emits a manifest with runtime/source/artifact hashes and PR provenance;
the tar contains only Python runtime, two PL firmware bins and that manifest.
The XSA remains on the PC; **never run its psu_init/FSBL on the current Linux**.

## Future authorized field session (not executed)

Issue #16 currently owns the camera/board time. No new wiring is needed for
offline work. Do not connect servos/FMC or change SW1, boot media or PS/DDR.
Every PL switch and driver unload/reload below needs current Citlali6 approval.

1. Schedule an exclusive FPGA Manager slot. Stop PC commands/vision, stop the
   camera via its existing `/stop`, verify capture exited and DMA halted, then
   stop the owned preview server. Unload `ah_camera0` manually only after safe
   shutdown. Stop the previous HIL service if present. DMA halt errors require
   manual recovery; do not reload through them.
2. Transfer a successfully built/reviewed tar and extract directly under `/run`
   tmpfs as `/run/amazinghand-camera-hil-new`. Run
   `python3 /run/amazinghand-camera-hil-new/unified.py preflight`.
   It checks kernel, package hashes, all active camera/PL drivers, open devices
   and surviving mmaps, DMA halt fault logs, HIL address ownership, PS HPM/HP1
   widths/resets, and live PL clocks. It reads **only PS MMIO**, never unknown
   camera/HIL registers before loading.
3. With that specific switch approved, in a dedicated foreground SSH terminal:
   `python3 /run/amazinghand-camera-hil-new/unified.py run --confirm-human-approved-reload --bind 192.28.14.153`.
   It holds `/run/amazinghand-pl.lock`, loads once, restores the firmware search
   path/flags, then verifies AHIL MAGIC/schema, forces STOP and serves on 8765.
   A failed load never authorizes an AHIL probe. No movement is automatic.
4. After `UNIFIED_HIL_READY`, the operator may load the **original** matching
   `ah_camera0.ko` with `matched_pl=1` and start the existing preview service.
   Do **not** call `load_z19_camera0.sh`: it would replace the unified PL.
   HIL continues in the same process while camera capture runs. No separate
   `start` command or stale `loaded.json` authorizes MMIO access.
5. With the same load/session still active, record 1080p frame/sequence/fps
   evidence and the PR #12 client's open/grasp/hold/release/stop ACK/counters,
   returned PL feedback, STOP and independent watchdog under camera/model load.
   Those are still **unmeasured acceptance requirements**.

Never run other/legacy loaders while the unified foreground service is alive:
they do not obey its new advisory lock. The lock does not prevent an unrelated
root process from reconfiguring PL; operator exclusivity is required. A new
service session always requires a new approved load, not a marker-file restart.

For rollback: stop capture/preview and safely unload the camera first; then
Ctrl+C the foreground HIL service (forces STOP), rerun preflight and, only with
rollback approval, run `unified.py restore-camera --confirm-human-approved-reload`.
It loads the packaged fixed-hash original camera bin and leaves the camera
driver/preview stopped. Manually load the original driver and start the original
preview afterwards. It never reinstalls dependencies, writes SD, reboots or
changes PS initialization. A programming failure needs operator diagnosis and
an approved rollback; it does not trigger an unrequested automatic PL switch.

## Recorded checks

`evidence/` contains the real 2020.1 rejection, source hash/address audit and
seven safety tests. `python -m compileall -q fpga/camera_hil`,
`python fpga/camera_hil/test_safety.py`, Tcl `info complete` and
`git diff --check` passed. The tests use fakes only for reload order/safety and
report rejection; they do not claim a built BD or board runtime. Earlier PR #13
HIL board results remain separate historical evidence.

No 2020.2 build, package conversion, deployment/rollback, simultaneous video/HIL,
load/STOP/watchdog performance, real servos or physical grasp was tested here.
