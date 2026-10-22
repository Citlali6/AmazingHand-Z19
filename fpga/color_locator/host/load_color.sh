#!/bin/sh
# Reviewed bench image only. No PS reinitialization and no SD/eMMC boot changes.
set -eu
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
fail(){ echo "COLOR_LOAD_REFUSED: $*" >&2; exit 1; }
[ "$#" = 2 ] || fail 'usage: FIRMWARE_PATH EXPECTED_SHA256'
[ "$(id -u)" = 0 ] && [ "$(uname -m)" = aarch64 ] || fail 'not root on AArch64'
[ "$(uname -r)" = 5.4.0-xilinx-v2020.2 ] || fail 'wrong baseline'
case "$1" in /lib/firmware/visiongrasp-color-20261022-*.bin) ;; *) fail 'wrong firmware location/name';; esac
[ "${#2}" = 64 ] || fail 'invalid hash length'
case "$2" in *[!a-f0-9]*) fail 'invalid hash';; esac
[ -f "$1" ] && [ "$(sha256sum "$1" | cut -d ' ' -f1)" = "$2" ] || fail 'hash mismatch'
[ ! -d /sys/module/ah_camera0 ] && [ ! -e /dev/mipi_cam ] || fail 'old MIPI camera active'
for p in /sys/bus/platform/devices/a0* /sys/bus/platform/devices/b0*; do
 [ ! -e "$p/driver" ] || fail "PL driver owns $p"
done
awk '
$1=="pl0_ref"{if($5<198000000||$5>202000000||$2<1)exit 1;a=1}
$1=="pl1_ref"{if($5<99000000||$5>101000000||$2<1)exit 1;b=1}
END{if(!a||!b)exit 1}' /sys/kernel/debug/clk/clk_summary || fail 'clock profile mismatch'
command -v flock >/dev/null || fail 'flock unavailable'
exec 9>/run/visiongrasp-color.lock
flock -n 9 || fail 'PL client still active'
[ ! -e /run/visiongrasp-color-20261022.loaded ] || fail 'color profile already marked loaded'
printf 0 > /sys/class/fpga_manager/fpga0/flags
printf '%s' "${1##*/}" > /sys/class/fpga_manager/fpga0/firmware
[ "$(cat /sys/class/fpga_manager/fpga0/state)" = operating ] || fail 'FPGA load failed'
printf '%s\n' "$2" > /run/visiongrasp-color-20261022.loaded
echo COLOR_PROFILE_LOADED_RUN_NATIVE_SELFTEST_NEXT
