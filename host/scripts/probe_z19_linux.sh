#!/bin/sh
# Read-only Z19 bring-up inventory. Does not configure FPGA, camera or servos.
set -u

section() { printf '\n%s\n' "$1"; }
run_if_present() {
    if command -v "$1" >/dev/null 2>&1; then
        "$@" 2>&1 || true
    else
        printf 'Unavailable: %s\n' "$1"
    fi
}

section 'Kernel and machine'
uname -a
if [ -r /etc/os-release ]; then
    cat /etc/os-release
elif [ -r /etc/issue ]; then
    cat /etc/issue
fi
if [ -r /proc/device-tree/model ]; then
    tr '\000' '\n' < /proc/device-tree/model
fi

section 'Root filesystem and storage'
run_if_present findmnt /
run_if_present lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
df -h /
if [ -r /proc/cmdline ]; then cat /proc/cmdline; fi

section 'Network addresses'
if command -v ip >/dev/null 2>&1; then
    ip -4 addr show
    ip route show
else
    run_if_present ifconfig
fi

section 'Python and build tools'
run_if_present python3 --version
run_if_present python --version
run_if_present gcc --version
run_if_present g++ --version
run_if_present make --version
run_if_present pkg-config --modversion opencv
run_if_present pkg-config --modversion opencv4
run_if_present getconf GNU_LIBC_VERSION
if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import importlib.util, platform; print("machine:", platform.machine()); print("modules:", {m: importlib.util.find_spec(m) is not None for m in ("pip", "cv2", "numpy", "ncnn", "yaml")})' 2>&1 || true
fi

section 'Camera, I2C and FPGA devices'
for node in /dev/mipi_cam /dev/video* /dev/i2c-*; do
    if [ -e "$node" ]; then ls -l "$node"; fi
done
if [ -d /sys/class/fpga_manager ]; then
    for manager in /sys/class/fpga_manager/*; do
        if [ -d "$manager" ]; then
            printf '%s\n' "$manager"
            for field in name state; do
                if [ -r "$manager/$field" ]; then cat "$manager/$field"; fi
            done
        fi
    done
fi
if [ -r /proc/modules ]; then
    awk '/mipi|video|xilinx|pl_allocator/ {print}' /proc/modules
fi

section 'Bring-up inventory complete; no hardware configuration was written'
