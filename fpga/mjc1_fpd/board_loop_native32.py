"""Z19 PS transport for actual MJC1 PL outputs and MuJoCo feedback.

Uses the HPM0_FPD profile at A0000000, version 1.1. The PS issues planned
grasp/release commands; all reported states/targets are read from the FPGA.
There is no software FSM fallback and no physical actuator output.
"""
import argparse
import ctypes
import json
import mmap
import socket
import struct
import time
from pathlib import Path

STATE = {0: 'IDLE', 1: 'PREGRASP', 2: 'CLOSING', 3: 'HOLD', 4: 'RELEASING', 5: 'PROTECT'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--probe', action='store_true')
    parser.add_argument('--pc', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=18765)
    parser.add_argument('--seconds', type=int, default=3600)
    args = parser.parse_args()
    io = ctypes.CDLL(str(Path(__file__).resolve().with_name('libmjc_mmio.so')))
    io.mjc_read32.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    io.mjc_read32.restype = ctypes.c_uint32
    io.mjc_write32.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32]
    io.mjc_write32.restype = None
    with open('/dev/mem', 'r+b', buffering=0) as device:
        with mmap.mmap(device.fileno(), 4096, access=mmap.ACCESS_WRITE, offset=0xA0000000) as registers:
            address = ctypes.addressof(ctypes.c_char.from_buffer(registers))
            def read(offset):
                return io.mjc_read32(address, offset)

            def write(offset, value):
                io.mjc_write32(address, offset, value)

            ident, version = read(0), read(4)
            if ident != 0x31434A4D or version != 0x00010001:
                raise RuntimeError('Wrong PL image: ID=%08x version=%08x' % (ident, version))
            print('PL_MJC1_VERIFIED base=0xa0000000 ID=0x%08x version=1.1' % ident, flush=True)
            if args.probe:
                return

            with socket.create_connection((args.pc, args.port), timeout=5) as connection:
                connection.settimeout(2)
                wire = connection.makefile('rwb', buffering=0)
                write(8, 0)
                write(12, 0x104)  # Clear a previous PROTECT state if necessary.
                time.sleep(.02)
                for channel in range(8):
                    write(0x10 + channel * 4, 950)
                write(0x30, 0xffffffff)
                write(0x34, 80)
                write(12, 3)  # Snapshot the open pose in the FPGA.
                write(8, 1)
                sequence, cycles, last_state = 0, 0, None
                phase, next_start, hold_start = 'WAIT', time.monotonic() + 1, None
                started, deadline = time.monotonic(), time.monotonic()
                try:
                    while time.monotonic() - started < args.seconds:
                        status = read(0x40)
                        state = status & 7
                        if state not in STATE or state == 5 or status & 0x40:
                            raise RuntimeError('PL protection/invalid state: 0x%x' % status)
                        targets = [read(0x50 + channel * 4) & 0xfff for channel in range(8)]
                        if state != last_state:
                            print('PL_STATE %s status=0x%x target_raw=%s' % (STATE[state], status, targets), flush=True)
                            last_state = state
                        sequence += 2
                        message = {'seq': sequence, 'state': state, 'target_raw': targets}
                        wire.write((json.dumps(message, separators=(',', ':')) + '\n').encode())
                        line = wire.readline(65537)
                        if not line or len(line) > 65536 or not line.endswith(b'\n'):
                            raise RuntimeError('MuJoCo response missing or oversized')
                        reply = json.loads(line)
                        positions, loads = reply.get('position_raw'), reply.get('load_raw')
                        if reply.get('seq') != sequence or not isinstance(positions, list) or len(positions) != 8 or not isinstance(loads, list) or len(loads) != 8:
                            raise RuntimeError('Invalid feedback frame')
                        for channel, (position, load) in enumerate(zip(positions, loads)):
                            if type(position) is not int or not 0 <= position <= 1800 or type(load) is not int or not 0 <= load <= 1023:
                                raise RuntimeError('Feedback value outside virtual ABI')
                            write(0x80 + channel * 4, position | (load << 12))
                        write(0xa0, sequence | 1)
                        if read(0x44) != sequence | 1:
                            raise RuntimeError('FPGA did not accept the feedback sequence')
                        now = time.monotonic()
                        if phase == 'WAIT' and now >= next_start:
                            for channel in range(8):
                                write(0x10 + channel * 4, 1450)
                            write(12, 1)
                            phase = 'GRASP'
                        elif phase == 'GRASP' and state == 3:
                            if hold_start is None:
                                hold_start = now
                            elif now - hold_start >= 1.5:
                                for channel in range(8):
                                    write(0x10 + channel * 4, 950)
                                write(12, 2)
                                phase = 'RELEASE'
                        elif phase == 'RELEASE' and state == 0:
                            cycles += 1
                            print('PL_CYCLE_COMPLETE cycle=%d accepted_seq=%d position_raw=%s' % (cycles, read(0x44), positions), flush=True)
                            phase, next_start, hold_start = 'WAIT', now + 2, None
                        if sequence % 100 == 0:
                            print('PL_FEEDBACK_ACK seq=%d position_raw=%s' % (sequence | 1, positions), flush=True)
                        deadline += .02
                        time.sleep(max(0, deadline - time.monotonic()))
                finally:
                    write(8, 3)  # Virtual PL estop on any transport termination.


if __name__ == '__main__':
    main()
