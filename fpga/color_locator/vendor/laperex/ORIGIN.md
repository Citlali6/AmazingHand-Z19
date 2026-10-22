# Upstream source, kept unmodified

- Repository: https://github.com/laperex/image_processing_fpga
- Commit: `0a33843ab7dee60cca22082db42e4f8eb4c180e1`
- License: MIT, copyright (c) 2026 Krishnadev K. Full notice in `LICENSE`.
- Original paths and SHA256: `UPSTREAM.json`.
- Files copied: `srcs/rtl/cv_types.sv`, `srcs/rtl/cv_rgb_to_hsv.sv`.

The upstream project targets PYNQ-Z2 with Vivado2024.1 and a Python3.14 build tool.
Only these two portable SystemVerilog source files are reused here. The upstream
board design, address map, AXI wrappers and build scripts are NOT imported.

The core is free running, with six registered pixel stages and no ready/enable
input. `../../rtl/vg_color_axis.sv` provides local buffering and credits. It never
feeds an unaccepted input pixel to the core, and reserves space for in-flight
pixels before accepting them. This addresses the upstream wrapper's documented
backpressure limitation without modifying the original math core.

Local tests cover 1024 numeric RGB/HSV vectors (H circular tolerance1, S tolerance2,
V exact), and 2064 stream beats with stalls, valid bubbles, SOF/EOL alignment,
frame-bound configuration snapshots and reset with pending pixels. These tests
are not camera/board, all-RGB exhaustive, or optical color calibration evidence.
