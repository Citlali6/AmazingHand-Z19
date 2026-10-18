# Explicit experimental Vivado 2020.1 reconstruction

Authorized by [Issue #17's follow-up](https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/issues/17#issuecomment-6246288827).
This route recreates the design in a **new** project from the original BD's
configuration; it does not open an unsupported old BD and change its version,
run upgrade_ip, overwrite any original XCI/BD, or alter the strict 2020.2 entry.
It uses only the installed Vivado/Vitis 2020.1. No new tool installation is needed.

```powershell
python fpga/camera_hil/experimental_2020_1/prepare.py --output F:/ah-camera-hil-2020.1-new --stage impl
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
2020.1 without removing a property. The reconstruction preserves every original
top-level block/connection/address and appends only M11/AHIL. Native XCI/BD
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
