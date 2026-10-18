# Explicit experimental Vivado 2020.1 reconstruction

Authorized by [Issue #17's follow-up](https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/issues/17#issuecomment-6246288827).
This route recreates the design in a **new** project from the original BD's
configuration; it does not open an unsupported old BD and change its version,
run upgrade_ip, overwrite any original XCI/BD, or alter the strict 2020.2 entry.
It uses only the installed Vivado/Vitis 2020.1. No new tool installation is needed.

```powershell
python fpga/camera_hil/experimental_2020_1/prepare.py --output F:/ah-camera-hil-2020.1-new --stage impl --repair-csi
& F:/Xilinx/Vivado/2020.1/bin/vivado.bat -mode batch -nojournal -log F:/ah-camera-hil-2020.1-new/vivado.log -source F:/ah-camera-hil-2020.1-new/rebuild.tcl
python fpga/camera_hil/audit.py --build F:/ah-camera-hil-2020.1-new
```

`probe` stops after actual catalog/property restoration and IP status. `validate`
restores the entire topology, adds AHIL, invokes real validate_bd_design and
generates output products. `synth` and `impl` continue to their respective runs.
Output destinations must not exist; source snapshots, generated projects and
reports stay there. `reconstruction.json` lists every converted block and the
exact generated Tcl hash. It is not a completion certificate. `validated.txt`
is written by Vivado only after validation returns successfully.

The 2020.1 catalog contains all original IP VLNVs and the supplied ALINX CSI and
Digilent Bayer/Gamma sources. All 1,012 archived PS properties are accepted by
2020.1 without removing a property. The unflagged reconstruction preserves every
original top-level block/connection/address and appends M11/AHIL. `--repair-csi`
also adds the explicitly audited shared-reference block and private scalar
calibration ports described below; original endpoint groups remain connected.
Native XCI/BD
serialization still differs from 2020.2; these are explicitly audited:

- PS `PSU__PROTECTION__SLAVES` adds the FPD_GPV and CCI_GPV descriptors. Original
  entries/flags remain unchanged. New XSA PS initialization must never run on
  the existing Linux: the added metadata is not board validated.
- Address-space serialization includes 40-bit/1T PS and 64-bit/16E VDMA metadata;
  all mapped and excluded segments retain their original values.
- Native XCI instance names change. Metadata of disabled PS AXI interfaces and
  the unconnected IRQ0 differs; connected HPM0/HP1 and IRQ1 stay unchanged.
- The 2020.1 xlconcat schema omits nonexistent input slots >=32; the six used
  inputs are unchanged. AXI-IIC advertises two outstanding accesses instead of
  one; its core model parameters are unchanged, and camera 0 uses PS I2C0.
- Metadata of other unconnected/disabled interfaces differs. No changed active
  image pipeline model parameter is accepted. `audit_xci.py` rejects differences
  outside the enumerated cases, in addition to the original BD semantic audit.

The native XCI implementations require real synthesis/implementation and later
independent board acceptance. Passing a catalog/property audit, BD validation or
even implementation does not establish real sensor capture in this profile.
The existing camera/HIL standalone profiles and original camera files remain
the recovery references. No board operations are part of this experiment, and
Issue #20 vision-to-control integration is outside its authorized scope.

After an implementation truly passes the unchanged timing/DRC/coverage and
bit/XSA gates, `package_linux.py` recognizes `experimental-camera-hil-2020.1`
and requires matching 2020.1 reports; all firmware hashes and rollback checks
remain mandatory. New firmware still needs separate current field approval.

## P0 private CSI repair

The [P0 authorization](https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/issues/17#issuecomment-6246782620)
adds `--repair-csi`. Omitting that flag reproduces the earlier reconstruction.
The flagged path makes five exact transformations only in the copied CSI IP:
four HDL files plus its component.xml scalar ports. `csi_patch.py` records
original/patched SHA256 and the auditor recomputes every expected byte from
the untouched archive. A single new `delay_reference` module is shared by all
four CSI instances; all existing connections, addresses and PS parameters stay.

- Real MMCME4_BASE M=6/D=1/O=4, BUFG feedback/output: unchanged measured PL0
  200.703980 MHz -> VCO 1204.223880 MHz -> IDELAY reference 301.055970 MHz.
  The original PL0 clock detector and AXI/stream domains remain on PL0.
- TIME/FIXED IDELAYE3 retains delay=20 ps and EN_VTC=1; REFCLK_FREQUENCY
  matches 301.055970. IDELAY reset now uses the common I/O reset instead of
  constant zero. Original IDELAYCTRL SIM_DEVICE=ULTRASCALE is correct for US+.
- Lock loss/reset asserts immediately; three reference-domain stages release
  the sequencer. All I/O primitive resets release together after 8 ref cycles,
  then all IDELAYCTRL resets together 32 ref cycles later (>106 ns).
  Primitive initial reset release does not require a sensor/byte clock or RDY.
  All four controller RDYs are synchronized in the common reference domain;
  each application separately synchronizes this condition and waits at least
  64 of its own byte clocks before accepting data. An absent camera therefore
  does not prevent the reference-domain calibration sequence from running.
- Original clock-loss detection is retained for runtime SERDES recovery after
  initial calibration. New synchronizer flops have ASYNC_REG/SHREG_EXTRACT
  attributes; complete CDC acceptance still requires real implementation.
- `mipi_nominal.xdc` models only the nominal source clocks derived from the
  local FL0214 REV1.0 manual and fl0214_2018-3-14 schematic p4
  (X1 OSC25MHz -> U12 5PB1102PGGI -> both CSI MCLK) and Sony IMX214 Software Reference
  0.0.6 pp47-49 plus existing sensor_table.h registers: OPCK=25/8*110 MHz,
  DCK=OPCK/2/1=171.875 MHz. It supplies no guessed external delays and no broad
  clock-group/false-path exceptions. Sensor/bridge/PCB/oscillator qualification
  is a separate signoff requirement; the nominal model is not a field reading.
- `fix_netlist.tcl` proves four VDMA URAM288 NONE/NONE instances and ties only
  disconnected cascade inputs to GND, leaving already grounded inputs alone.
  It checks actual connections and driver types. It considers only proved
  unused FIFO status outputs for no-load cleanup; DONT_TOUCH/security-protected
  vendor nets are retained. No VDMA mode/depth/width, DRC severity or gate changes.

The clock/reset requirements are from [DS925 I/O delay characteristics](https://docs.amd.com/r/en-US/ds925-zynq-ultrascale-plus/Input/Output-Delay-Switching-Characteristics),
[DS925 MMCM characteristics](https://docs.amd.com/r/en-US/ds925-zynq-ultrascale-plus/MMCM-Switching-Characteristics)
and [UG571 v1.16 pp188-194](https://docs.amd.com/api/khub/documents/kFbaUC5HGcXyGNauhgU6Gw/content).
The local Sony/module manuals are not redistributed here. The older archived
camera, validated firmware and strict entry are never patched by this option.
