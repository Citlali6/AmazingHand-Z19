# MJC1 FPD board validation, 2026-10-18

Independent verification directory; existing repositories and uncommitted work are preserved.
Inputs are copied from the existing feature/fpga-ps-mujoco-bridge checkout.

Changes relative to the earlier MJC1 image:
- Match the verified camera/Linux baseline: HPM0_FPD 128 bits, PL1 approximately 100 MHz, base 0xA0000000, range 4 KiB.
- Use Xilinx AXI Interconnect for 128-bit AXI4 to 32-bit AXI4-Lite conversion.
- Preserve active-low PS reset polarity explicitly.
- Auxiliary reset is active low and must be tied HIGH. The initial FPD attempt incorrectly tied it low; its artifact must not be used. Only the `r2` bit/bin/XSA has this wiring corrected.
- Feedback commits take priority over the watchdog increment.
- The board client writes planned targets at 0x010 and reads actual PL FSM targets at 0x050; it checks the committed feedback sequence.

This image contains no physical servo outputs and replaces the camera PL profile while loaded. Nothing is written to boot storage.
Do not treat generation or local tests as proof of a completed board loop; board evidence is required.

## Confirmed running configuration

Real-board validation now passes: see `out/board_validation.json` (at least 17 completed cycles, matching FPGA feedback acknowledgements), `out/pl_trace.jsonl`, and `out/live_pl_mujoco.png`.

Use only the reset-fixed `out/mjc1_fpd_r2.bit.bin`, SHA256 `8e8b6566a3cdbe0e276852956b1d4c60b4fd74c8e4828e149509527ee0a4a8d4`. The earlier `out/mjc1_fpd.bit.bin` is an explicitly failed reset-debug image.

The active board program is `/opt/amazinghand/mjc1-fpd-20261018/board_loop_native32.py`, using `libmjc_mmio.so` compiled from `mmio.c`. Do not run the earlier deployed `board_loop.py` using Python-buffer MMIO; that attempt failed during feedback. Native full-width target/staging/commit checks passed before starting the continuous loop.

PC view: run `pc_observer.py` with the existing `sim/.venv_mjc/Scripts/python.exe` from the bridge checkout. It listens only on `127.0.0.1:8765`. The running SSH session forwards remote loopback `18765` to that listener. No firewall rules or persistent credentials were added.

After a board reboot, keep all PL users stopped, run the guarded `load_mjc1_r2.sh` with the raw SHA256 above, then run `./mmio_check --rwtest` before the control client. Preserve existing evidence by choosing a new log filename. The native library and diagnostic build on the board:

```sh
gcc -O2 -Wall -Wextra -Werror -fPIC -shared mmio.c -o libmjc_mmio.so
gcc -O2 -Wall -Wextra -Werror -DMJC_MMIO_MAIN mmio.c -o mmio_check
python3 -u board_loop_native32.py --pc 127.0.0.1 --port 18765 --seconds 3600
```

The current demonstration repeats opening/closing/holding/releasing for up to one hour. Closing the viewer or losing transport ends the client and requests the virtual PL estop. HOLD currently uses the FPGA closing timer; object contact and physical force are not part of this acceptance.
