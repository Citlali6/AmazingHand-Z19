#!/usr/bin/env python3
"""Z19 Linux transport only: TCP NDJSON <-> isolated HIL PL AXI bank.

Python 3.7 compatible. No trajectory generation, simulator, or fallback device.
Run only after loading the matching isolated hardware/OS platform.
"""
import argparse
import json
import mmap
import os
import signal
import socket
import struct
import time

PROTOCOL = 'amazinghand-hil/1'
STATES = ('IDLE', 'PREGRASP', 'CLOSING', 'HOLD', 'RELEASING', 'PROTECT')
COMMANDS = dict(tick=0, reset=1, open=2, grasp=3, hold=4, release=5, stop=6)


def uint(value, maximum, name):
    if type(value) is not int or not 0 <= value <= maximum:
        raise ValueError('%s must be integer in 0..%d' % (name, maximum))
    return value


def vector(value, maximum, name):
    if not isinstance(value, list) or len(value) != 8:
        raise ValueError('%s requires eight channels' % name)
    return [uint(v, maximum, name) for v in value]


def validate(frame):
    if not isinstance(frame, dict) or frame.get('protocol') != PROTOCOL:
        raise ValueError('protocol mismatch')
    cmd = frame.get('cmd')
    if cmd == 'hello':
        return None
    if not isinstance(cmd, str) or cmd not in COMMANDS:
        raise ValueError('unknown command')
    seq = uint(frame.get('seq'), 0xffffffff, 'seq')
    heartbeat = uint(frame.get('heartbeat'), 0xffffffff, 'heartbeat')
    if not seq or heartbeat != seq:
        raise ValueError('seq starts at 1; heartbeat must equal seq')
    feedback = frame.get('feedback')
    if not isinstance(feedback, dict):
        raise ValueError('feedback required')
    return dict(cmd=COMMANDS[cmd], seq=seq, heartbeat=heartbeat,
                target=vector(frame.get('target_raw'), 4095, 'target_raw'),
                position=vector(feedback.get('position_raw'), 4095, 'position_raw'),
                load=vector(feedback.get('load_raw'), 1023, 'load_raw'),
                online=uint(feedback.get('online_mask'), 255, 'online_mask'))


class PlDevice:
    def __init__(self, base=0x80000000, path='/dev/mem'):
        self.mem = None
        fd = os.open(path, os.O_RDWR | getattr(os, 'O_SYNC', 0))
        try:
            self.mem = mmap.mmap(fd, 4096, offset=base)
        finally:
            os.close(fd)
        if self.read(0) != 0x4148494c or self.read(4) != 1:
            self.mem.close()
            self.mem = None
            raise RuntimeError('not AHIL schema 1; refusing legacy/camera hardware')

    def read(self, offset):
        return struct.unpack_from('<I', self.mem, offset)[0]

    def write(self, offset, value):
        struct.pack_into('<I', self.mem, offset, value)

    def stop(self):
        self.write(0xf0, 1)
        self.read(0)  # complete device write before returning

    def transact(self, request):
        self.write(8, request['cmd'])
        self.write(12, request['online'])
        self.write(16, request['seq'])
        self.write(20, request['heartbeat'])
        for index in range(8):
            self.write(0x20 + index * 4, request['target'][index])
            self.write(0x40 + index * 4, request['position'][index])
            self.write(0x60 + index * 4, request['load'][index])
        self.write(0x18, 1)
        self.read(0)
        # AXI completed; allow registered FSM command and open's 3-clock sequence.
        time.sleep(0.0001)
        return self.snapshot(request['seq'])

    def snapshot(self, seq=None):
        self.write(0x1c, 1)
        self.read(0)
        words = [self.read(0x100 + i * 4) for i in range(32)]
        if words[0] >= len(STATES):
            self.stop()
            raise RuntimeError('invalid PL state')
        return dict(protocol=PROTOCOL, seq=words[4] if seq is None else seq,
                    source='pl', state=STATES[words[0]], torque_enabled=bool(words[1]),
                    fault=words[2], pl_tick=words[3], accepted_seq=words[4],
                    feedback_seq=words[5], command_count=words[6], feedback_count=words[7],
                    target_raw=words[8:16], position_raw=words[16:24], load_raw=words[24:32])

    def close(self):
        if self.mem is not None:
            try:
                self.stop()
            finally:
                self.mem.close()
                self.mem = None


def serve_connection(conn, device):
    # Timeout is transport cleanup only; PL enforces 500ms independently.
    conn.settimeout(0.4)
    with conn.makefile('rwb') as stream:
        while True:
            line = stream.readline(4097)
            if not line:
                return
            if len(line) > 4096 or not line.endswith(b'\n'):
                raise ValueError('frame exceeds 4096 bytes or missing newline')
            request = validate(json.loads(line))
            result = device.snapshot() if request is None else device.transact(request)
            stream.write((json.dumps(result, separators=(',', ':')) + '\n').encode('ascii'))
            stream.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bind', default='127.0.0.1', help='board interface; explicitly choose trusted LAN IP')
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--base', type=lambda v: int(v, 0), default=0x80000000)
    args = parser.parse_args()
    def shutdown(signum, current_frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, shutdown)
    device = PlDevice(args.base)
    try:
        device.stop()
        with socket.socket() as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind((args.bind, args.port))
            listener.listen(1)
            print('AHIL PL schema1 ready on %s:%d' % (args.bind, args.port), flush=True)
            while True:
                conn, peer = listener.accept()
                try:
                    with conn:
                        serve_connection(conn, device)
                except (ValueError, OSError, RuntimeError) as error:
                    print('session stopped: %s' % error, flush=True)
                finally:
                    device.stop()
    except KeyboardInterrupt:
        pass
    finally:
        device.close()


if __name__ == '__main__':
    main()
