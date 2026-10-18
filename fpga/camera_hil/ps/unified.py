#!/usr/bin/env python3
"""RAM-only camera/HIL loader and foreground HIL service (Python 3.7 stdlib).

No detached 'start' action: only a successful load in this same locked process
permits AHIL AXI access. A saved boot_id/loaded.json cannot identify current PL.
The camera may start AFTER the HIL service reports ready. Reload/rollback always
requires it to be stopped and unloaded by an authorized operator beforehand.
"""
import argparse
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

ROOT = Path(__file__).resolve().parent
MANAGER = Path('/sys/class/fpga_manager/fpga0')
FW_PATH = Path('/sys/module/firmware_class/parameters/path')
CAMERA_SHA = 'e25e9bc7fd4c2008c7a198a91bc4937716b333259d08da7ed777d8ffe9b3384b'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verified_manifest():
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    require(manifest['profile'] == 'camera-hil/1' and manifest['base'] == 0xa1000000
            and manifest['clock_hz'] == 200703980 and manifest['data_width'] == 128,
            'wrong unified profile')
    files = manifest['files_sha256']
    require(set(files) == {'unified.py', 'hil_server.py', 'camera-hil.bin', 'camera-original.bin'},
            'incomplete runtime package')
    for name, expected in files.items():
        require(digest(ROOT / name) == expected, 'package hash mismatch: ' + name)
    require(files['camera-original.bin'] == CAMERA_SHA, 'unreviewed camera fallback')
    return manifest


def reject_active_users(modules, devices, processes):
    """Pure guard shared by preflight and safety regression tests."""
    require('ah_camera0' not in modules and 'mipi_cam' not in modules,
            'camera driver loaded: stop capture/preview, confirm DMA halt, then unload manually')
    for name, bound in devices:
        try:
            address = int(name.split('.')[0], 16)
        except ValueError:
            continue
        require(not (0x80000000 <= address < 0xc0000000 and bound),
                'bound PL driver: ' + name)
    require(not processes, 'active PL/device mappings: ' + ', '.join(processes))


def reject_dma_fault(log):
    require('DMA failed to halt' not in log and 'refusing to free unhalted DMA' not in log,
            'camera DMA halt failure recorded; preserve state and request manual recovery')


def live_users():
    users = []
    # No PL MMIO is read to check for DMA. Unloaded reviewed camera module and
    # absence of mappings are prerequisites; unknown/broken DMA needs manual recovery.
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit() or int(proc.name) == os.getpid():
            continue
        try:
            for fd in (proc / 'fd').iterdir():
                try:
                    target = os.readlink(str(fd))
                except FileNotFoundError:
                    continue
                if target in ['/dev/mem', '/dev/ah_camera0', '/dev/mipi_cam'] or target.startswith('/dev/uio'):
                    users.append(proc.name + ':' + target)
            # mmap can outlive its fd. Check maps as well, including /dev/mem.
            for line in (proc / 'maps').read_text().splitlines():
                if any(path in line for path in ['/dev/mem', '/dev/ah_camera0', '/dev/mipi_cam', '/dev/uio']):
                    users.append(proc.name + ':mmap')
        except (FileNotFoundError, ProcessLookupError):
            continue
    return sorted(set(users))


def preflight():
    require(os.geteuid() == 0, 'board root required')
    require(os.uname().machine == 'aarch64' and os.uname().release == '5.4.0-xilinx-v2020.2',
            'wrong board Linux profile')
    require(ROOT.parent == Path('/run') and ROOT.name.startswith('amazinghand-camera-hil-'),
            'extract directly below /run/amazinghand-camera-hil-*')
    require(any(line.split()[1:3] == ['/run', 'tmpfs']
                for line in Path('/proc/mounts').read_text().splitlines()), '/run must be RAM tmpfs')
    require(not Path('/dev/ah_camera0').exists() and not Path('/dev/mipi_cam').exists(),
            'camera device still present')
    modules = {line.split()[0] for line in Path('/proc/modules').read_text().splitlines()}
    devices = [(dev.name, (dev / 'driver').exists())
               for dev in Path('/sys/bus/platform/devices').iterdir()]
    reject_active_users(modules, devices, live_users())
    reject_dma_fault(subprocess.check_output(['dmesg'], universal_newlines=True))
    for line in Path('/proc/iomem').read_text().splitlines():
        low, high = (int(v, 16) for v in line.strip().split(' : ')[0].split('-'))
        require(high < 0xa1000000 or low > 0xa1000fff, 'AHIL range owned: ' + line.strip())
    clocks = {}
    for line in Path('/sys/kernel/debug/clk/clk_summary').read_text().splitlines():
        cols = line.split()
        if cols and cols[0] in ['pl0_ref', 'pl1_ref']:
            require(int(cols[1]) > 0, 'disabled PL clock')
            clocks[cols[0]] = int(cols[4])
    require(abs(clocks.get('pl0_ref', 0) - 200703980) <= 1000, 'PL0 clock mismatch')
    require(abs(2 * clocks.get('pl1_ref', 0) - clocks['pl0_ref']) <= 1000,
            'PL1 clock must match preserved 2:1 reference profile')
    registers = {}
    fd = os.open('/dev/mem', os.O_RDONLY | os.O_SYNC)
    try:
        # Read only known PS registers: HPM0 128-bit, HP1 128-bit, reset released.
        # Never probe camera/VDMA/AHIL addresses before successful programming.
        for address, mask, expected in [(0xfd615000, 0x300, 0x200),
                                        (0xfd390000, 3, 0), (0xfd390014, 3, 0),
                                        (0xfd1a0100, 0x1f80, 0)]:
            with mmap.mmap(fd, 4096, flags=mmap.MAP_SHARED, prot=mmap.PROT_READ,
                           offset=address & ~4095) as mem:
                result = struct.unpack_from('<I', mem, address & 4095)[0]
                require(result & mask == expected, 'PS profile mismatch: ' + hex(address))
                registers[hex(address)] = hex(result)
    finally:
        os.close(fd)
    require(MANAGER.is_dir() and FW_PATH.exists(), 'FPGA Manager/path override missing')
    return dict(clocks=clocks, ps_registers=registers, pl_mmio_read=False,
                camera_unloaded=True, active_pl_users=False)


def program(path):
    old_path = FW_PATH.read_text().strip()
    old_flags = (MANAGER / 'flags').read_text().strip()
    try:
        FW_PATH.write_text(str(path.parent))
        (MANAGER / 'flags').write_text('0')
        (MANAGER / 'firmware').write_text(path.name)
        require((MANAGER / 'state').read_text().strip() == 'operating', 'FPGA programming failed')
    finally:
        FW_PATH.write_bytes(old_path.encode() + b'\0')
        (MANAGER / 'flags').write_text(old_flags)
        require(FW_PATH.read_text().strip() == old_path, 'firmware search path restore failed')


def serve(device, bind, port):
    from hil_server import serve_connection
    with socket.socket() as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((bind, port))
        listener.listen(1)
        print('UNIFIED_HIL_READY %s:%d; camera driver/preview may now be started manually' %
              (bind, port), flush=True)
        while True:
            conn, peer = listener.accept()
            try:
                with conn:
                    serve_connection(conn, device)
            except (ValueError, OSError, RuntimeError) as error:
                print('HIL session stopped: ' + str(error), flush=True)
            finally:
                device.stop()


def approved_action(action, approved, manifest, bind, port):
    require(action == 'preflight' or approved,
            'PL reload requires explicit current Citlali6 approval; --confirm-human-approved-reload')
    facts = preflight()
    print(json.dumps(facts, sort_keys=True), flush=True)
    if action == 'preflight':
        return
    if action == 'restore-camera':
        program(ROOT / 'camera-original.bin')
        print('ORIGINAL_CAMERA_PL_RESTORED; driver/preview remain stopped', flush=True)
        return
    program(ROOT / 'camera-hil.bin')
    # Keep loading and MMIO access in one process/session. No state marker can
    # authorize a later 'start' after another full PL load.
    from hil_server import PlDevice
    device = PlDevice(manifest['base'])
    try:
        device.stop()
        print(json.dumps(dict(initial_pl=device.snapshot())), flush=True)
        serve(device, bind, port)
    finally:
        device.close()


def main():
    import fcntl  # Linux-only; pure safety checks remain testable on the PC.
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['preflight', 'run', 'restore-camera'])
    parser.add_argument('--confirm-human-approved-reload', action='store_true')
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--port', default=8765, type=int)
    args = parser.parse_args()
    require(os.geteuid() == 0 and ROOT.parent == Path('/run'), 'run as board root from /run only')
    # One shared lock across all NEW unified packages, held for the full HIL
    # session. Other/legacy loaders do not obey it: operator exclusivity remains mandatory.
    with Path('/run/amazinghand-pl.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        manifest = verified_manifest()
        def shutdown(signum, frame):
            raise KeyboardInterrupt
        signal.signal(signal.SIGTERM, shutdown)
        approved_action(args.action, args.confirm_human_approved_reload, manifest, args.bind, args.port)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        sys.exit('UNIFIED_DEPLOY_REFUSED: ' + str(error))
