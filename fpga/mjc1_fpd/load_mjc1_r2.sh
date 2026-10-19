#!/bin/sh
# Load only the independently built virtual-only MJC1 FPD image.
set -eu
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "MJC1_LOAD_REFUSED: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'root required'
[ "$(uname -m)" = aarch64 ] || fail 'wrong architecture'
[ "$(uname -r)" = 5.4.0-xilinx-v2020.2 ] || fail 'wrong Linux baseline'
[ "$#" = 1 ] || fail 'expected raw firmware SHA256'
[ ! -d /sys/module/ah_camera0 ] || fail 'camera module still loaded'
[ ! -e /dev/mipi_cam ] || fail 'another camera driver exists'
for path in /sys/bus/platform/devices/a0*; do
    [ ! -e "$path/driver" ] || fail "active PL driver: $path"
done
awk '
$1=="pl0_ref" { if ($5 < 198000000 || $5 > 202000000 || $2 < 1) exit 1; a=1 }
$1=="pl1_ref" { if ($5 < 99000000 || $5 > 101000000 || $2 < 1) exit 1; b=1 }
END { if (!a || !b) exit 1 }
' /sys/kernel/debug/clk/clk_summary || fail 'unexpected live PL clocks'
firmware=/lib/firmware/amazinghand-mjc1-fpd-20261018-r2.bin
[ -f "$firmware" ] || fail 'firmware missing'
[ "$(sha256sum "$firmware" | cut -d ' ' -f1)" = "$1" ] || fail 'firmware hash mismatch'
printf 0 > /sys/class/fpga_manager/fpga0/flags
printf '%s' amazinghand-mjc1-fpd-20261018-r2.bin > /sys/class/fpga_manager/fpga0/firmware
[ "$(cat /sys/class/fpga_manager/fpga0/state)" = operating ] || fail 'FPGA manager did not finish'
echo MJC1_FPD_LOADED
