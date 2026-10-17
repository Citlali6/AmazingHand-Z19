#!/usr/bin/env python3
"""Temporary Z19 camera-Linux HIL deployment. Python 3.7, standard library only.

All package files, logs and state live in /run (RAM). Never runs psu_init, changes
clocks, writes SD boot files, unloads drivers, or starts motion automatically.
"""
import argparse
import fcntl
import hashlib
import json
import mmap
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
MANAGER = Path('/sys/class/fpga_manager/fpga0')
FW_PATH = Path('/sys/module/firmware_class/parameters/path')
CAMERA = Path('/lib/firmware/amazinghand-camera-28e1e3e7-20261010.bin')
CAMERA_SHA = 'e25e9bc7fd4c2008c7a198a91bc4937716b333259d08da7ed777d8ffe9b3384b'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def verified_manifest():
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    require(manifest['profile'] == 'linux-sd', 'wrong package profile')
    require(manifest['base'] == 0xa1000000 and manifest['clock_hz'] == 200703980,
            'wrong AXI/clock profile')
    for name, expected in manifest['files_sha256'].items():
        require(Path(name).name == name, 'unsafe package path')
        require(digest(ROOT / name) == expected, 'package hash mismatch: ' + name)
    return manifest


def preflight():
    require(os.geteuid() == 0, 'board root required')
    require(os.uname().machine == 'aarch64' and
            os.uname().release == '5.4.0-xilinx-v2020.2', 'wrong Linux profile')
    require(ROOT.parent == Path('/run') and ROOT.name.startswith('amazinghand-hil-'),
            'extract package directly below /run/amazinghand-hil-*')
    mounts = Path('/proc/mounts').read_text().splitlines()
    require(any(line.split()[1:3] == ['/run', 'tmpfs'] for line in mounts),
            '/run must be RAM tmpfs')
    require(not Path('/sys/module/ah_camera0').exists() and
            not Path('/dev/mipi_cam').exists(), 'camera active: stop/unload manually first')
    # Full configuration replaces all PL; refuse any bound PL platform driver.
    for dev in Path('/sys/bus/platform/devices').iterdir():
        try:
            address = int(dev.name.split('.')[0], 16)
        except ValueError:
            continue
        require(not (0x80000000 <= address < 0xc0000000 and (dev / 'driver').exists()),
                'active PL driver: ' + dev.name)
    for line in Path('/proc/iomem').read_text().splitlines():
        bounds = line.strip().split(' : ')[0].split('-')
        if len(bounds) == 2:
            low, high = (int(v, 16) for v in bounds)
            require(high < 0xa1000000 or low > 0xa1000fff,
                    'HIL range already owned: ' + line.strip())
    clocks = {}
    for line in Path('/sys/kernel/debug/clk/clk_summary').read_text().splitlines():
        cols = line.split()
        if cols and cols[0] == 'pl0_ref':
            require(int(cols[1]) > 0, 'PL0 clock disabled')
            clocks['pl0_ref'] = int(cols[4])
    require(abs(clocks.get('pl0_ref', 0) - 200703980) <= 1000, 'live PL0 clock mismatch')
    registers = {}
    fd = os.open('/dev/mem', os.O_RDONLY | os.O_SYNC)
    try:
        # FPD_SLCR AFI_FS: HPM0 128-bit; CRF reset: PL interfaces out of reset.
        # Read only PS registers, NEVER probe unconfigured AXI addresses.
        for addr, mask, expected in [(0xfd615000, 0x300, 0x200),
                                     (0xfd1a0100, 0x1f80, 0)]:
            with mmap.mmap(fd, 4096, flags=mmap.MAP_SHARED, prot=mmap.PROT_READ,
                           offset=addr & ~4095) as mem:
                value = struct.unpack_from('<I', mem, addr & 4095)[0]
                registers[hex(addr)] = hex(value)
                require(value & mask == expected, 'PS profile mismatch: ' + hex(addr))
    finally:
        os.close(fd)
    require(MANAGER.exists() and FW_PATH.exists(), 'FPGA manager/custom firmware path missing')
    require(CAMERA.is_file() and digest(CAMERA) == CAMERA_SHA, 'camera rollback image unavailable')
    return dict(kernel=os.uname().release, clocks=clocks, registers=registers,
                rollback_sha256=CAMERA_SHA)


def server_pid():
    path = ROOT / 'service.pid'
    if not path.exists():
        return None
    pid = int(path.read_text())
    proc = Path('/proc') / str(pid) / 'cmdline'
    if not proc.exists():
        return None
    require(str(ROOT / 'hil_server.py').encode() in proc.read_bytes().split(b'\0'),
            'PID belongs to another process; refusing signal')
    return pid


def stop():
    pid = server_pid()
    if pid is None:
        return
    os.kill(pid, signal.SIGTERM)
    for _ in range(50):
        proc = Path('/proc') / str(pid)
        if not proc.exists() or ') Z ' in (proc / 'stat').read_text():
            (ROOT / 'service.pid').unlink()
            return
        time.sleep(0.1)
    raise RuntimeError('service did not stop; refusing PL reload')


def program(path):
    require(server_pid() is None, 'stop HIL service before reloading PL')
    old_path = FW_PATH.read_text().strip()
    old_flags = (MANAGER / 'flags').read_text().strip()
    try:
        FW_PATH.write_text(str(path.parent))
        (MANAGER / 'flags').write_text('0')
        (MANAGER / 'firmware').write_text(path.name)
        require((MANAGER / 'state').read_text().strip() == 'operating', 'FPGA load failed')
    finally:
        # A zero-length write does not invoke the kernel setter. A terminating
        # NUL also restores the original empty value (verified on this kernel).
        FW_PATH.write_bytes(old_path.encode() + b'\0')
        (MANAGER / 'flags').write_text(old_flags)
        require(FW_PATH.read_text().strip() == old_path, 'firmware search path restore failed')


def loaded():
    state = json.loads((ROOT / 'loaded.json').read_text())
    require(state['boot_id'] == Path('/proc/sys/kernel/random/boot_id').read_text().strip()
            and state['manifest_sha256'] == digest(ROOT / 'manifest.json'),
            'load this package again after reboot/package change')
    require((MANAGER / 'state').read_text().strip() == 'operating', 'FPGA not operating')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['preflight', 'load', 'start', 'stop', 'status', 'restore-camera'])
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    require(os.geteuid() == 0, 'root required')
    require(ROOT.parent == Path('/run'), 'run only from the RAM package')
    with (ROOT / 'deployment.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        manifest = verified_manifest()
        if args.action == 'stop':
            stop()
        elif args.action == 'status':
            print(json.dumps(dict(pid=server_pid(), fpga=(MANAGER / 'state').read_text().strip())))
        elif args.action == 'preflight':
            print(json.dumps(preflight(), sort_keys=True))
        elif args.action == 'load':
            facts = preflight()
            marker = ROOT / 'loaded.json'
            if marker.exists():
                marker.unlink()
            program(ROOT / 'ah-hil-linux-sd.bin')
            # Only after successful programming may the HIL AXI bank be read.
            from hil_server import PlDevice
            device = PlDevice(manifest['base'])
            try:
                device.stop()
                facts['initial_pl'] = device.snapshot()
            finally:
                device.close()
            facts['boot_id'] = Path('/proc/sys/kernel/random/boot_id').read_text().strip()
            facts['manifest_sha256'] = digest(ROOT / 'manifest.json')
            marker.write_text(json.dumps(facts, indent=2) + '\n')
            print(json.dumps(facts, sort_keys=True))
        elif args.action == 'start':
            preflight()
            loaded()
            require(server_pid() is None, 'service already running')
            with (ROOT / 'service.log').open('ab', buffering=0) as output:
                proc = subprocess.Popen([sys.executable, '-u', str(ROOT / 'hil_server.py'),
                                         '--base', hex(manifest['base']), '--bind', args.bind,
                                         '--port', str(args.port)], stdin=subprocess.DEVNULL,
                                        stdout=output, stderr=output, start_new_session=True,
                                        close_fds=True)
            (ROOT / 'service.pid').write_text(str(proc.pid))
            for _ in range(50):
                require(proc.poll() is None, 'service exited: see service.log')
                try:
                    with socket.create_connection((args.bind, args.port), timeout=0.1) as conn:
                        conn.sendall(b'{"protocol":"amazinghand-hil/1","cmd":"hello"}\n')
                        reply = json.loads(conn.makefile('rb').readline(4097))
                        require(reply.get('source') == 'pl', 'invalid service reply')
                        print(json.dumps(dict(pid=proc.pid, ready=reply)))
                        return
                except OSError:
                    time.sleep(0.1)
            stop()
            raise RuntimeError('service not ready')
        else:
            stop()
            preflight()
            program(CAMERA)
            marker = ROOT / 'loaded.json'
            if marker.exists():
                marker.unlink()
            print('CAMERA_PL_RESTORED; camera driver/preview remain stopped')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError) as error:
        sys.exit('HIL_DEPLOY_REFUSED: ' + str(error))
