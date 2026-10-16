#!/bin/sh
# Manual bench loader for the reviewed camera PL. Does not change SD boot files.
set -eu
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "CAMERA_LOAD_REFUSED: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'root required'
[ "$(uname -m)" = aarch64 ] || fail 'not board AArch64'
[ "$(uname -r)" = 5.4.0-xilinx-v2020.2 ] || fail 'kernel profile mismatch'
[ "$#" = 2 ] || fail 'usage: load_z19_camera0.sh FIRMWARE.bin MODULE.ko'
firmware=$1
module=$2
[ -f "$firmware" ] && [ -f "$module" ] || fail 'missing firmware or module'
[ "$(modinfo -F name "$module")" = ah_camera0 ] || fail 'unexpected module'
[ "$(modinfo -F vermagic "$module")" = '5.4.0-xilinx-v2020.2 SMP mod_unload aarch64' ] || fail 'module kernel ABI mismatch'
[ ! -d /sys/module/ah_camera0 ] || fail 'camera module already loaded; stop and unload first'
[ ! -e /dev/mipi_cam ] || fail 'another camera driver is present'
[ -e /dev/i2c-0 ] && [ -e /dev/mem ] || fail 'PS I2C0 or register access missing'
[ -w /sys/class/fpga_manager/fpga0/firmware ] || fail 'FPGA manager unavailable'
[ "$(sha256sum "$firmware" | cut -d ' ' -f1)" = e25e9bc7fd4c2008c7a198a91bc4937716b333259d08da7ed777d8ffe9b3384b ] || fail 'unreviewed bitstream'
case "$firmware" in /lib/firmware/*.bin) ;; *) fail 'firmware must be in /lib/firmware' ;; esac
name=${firmware##*/}
case "$name" in *[!a-zA-Z0-9_.-]*) fail 'unsafe firmware name' ;; esac
# No active platform driver may own the camera AXI range during full reload.
for path in /sys/bus/platform/devices/a0*; do
    [ ! -e "$path/driver" ] || fail "active PL driver: $path"
done
awk '
$1=="pl0_ref" { if ($5 < 198000000 || $5 > 202000000 || $2 < 1) exit 1; a=1 }
$1=="pl1_ref" { if ($5 < 99000000 || $5 > 101000000 || $2 < 1) exit 1; b=1 }
END { if (!a || !b) exit 1 }
' /sys/kernel/debug/clk/clk_summary || fail 'PL clocks differ from reviewed 200/100 MHz profile'
python3 - <<'PY' || fail 'PS HP1 interface configuration mismatch'
import mmap, os, struct
fd = os.open('/dev/mem', os.O_RDONLY | os.O_SYNC)
try:
    for address, mask, expected in [(0xfd615000, 0x300, 0x200),
                                    (0xfd390000, 3, 0), (0xfd390014, 3, 0),
                                    (0xfd1a0100, 0x1f80, 0)]:
        with mmap.mmap(fd, 4096, flags=mmap.MAP_SHARED, prot=mmap.PROT_READ,
                       offset=address & ~4095) as registers:
            value = struct.unpack_from('<I', registers, address & 4095)[0]
            if value & mask != expected:
                raise RuntimeError('PS register mismatch at %#x' % address)
finally:
    os.close(fd)
PY
printf 0 > /sys/class/fpga_manager/fpga0/flags
printf '%s' "$name" > /sys/class/fpga_manager/fpga0/firmware
[ "$(cat /sys/class/fpga_manager/fpga0/state)" = operating ] || fail 'FPGA programming failed'
insmod "$module" matched_pl=1
[ -c /dev/ah_camera0 ] || fail 'driver device missing'
echo CAMERA_PROFILE_LOADED
