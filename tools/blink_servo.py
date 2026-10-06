#!/usr/bin/env python3
"""blink_servo.py - minimal control test: swing ONE servo back and forth.

First handshake of the whole chain (PC -> transparent UART / direct -> servo).
No grasp logic here, just "can we make it move".

Wiring (servo 5V MUST come from an independent supply, common GND!):
  servo V+   -> 5V supply +     (power bank / adapter, 2A is enough for one)
  servo GND  -> 5V supply - AND STM32 GND
  servo DATA -> STM32 PA9 (via firmware/stm32 passthrough) or USB-TTL TX (1k resistor)

Usage:
  python tools/blink_servo.py --port COM5 --id 1 --via mcu   # through STM32
  python tools/blink_servo.py --port COM3 --id 1 --via raw   # USB-TTL direct

Effect: PING -> torque on -> swing 3x (mid <-> mid+60deg) -> torque off.
Ctrl+C aborts safely (torque released).
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))

from app.control import scs_protocol as sp  # noqa: E402

MID = 2048
SWING = 647          # about +60 deg (4096 steps / 360 deg)
SWEEP_SPEED = 300    # slow enough to watch


def open_port(port: str, baud: int):
    import serial  # pyserial

    ser = serial.Serial(port, baud, timeout=0.2)
    ser.reset_input_buffer()
    return ser


def mcu_transact(ser, frame: bytes) -> bytes | None:
    """Through STM32 passthrough: length-prefixed protocol (firmware/stm32)."""
    ser.write(bytes([len(frame)]) + frame)
    rl = ser.read(1)
    if not rl or rl[0] == 0:
        return None
    return ser.read(rl[0]) or None


def raw_transact(ser, frame: bytes) -> bytes | None:
    """USB-TTL direct: half-duplex, drain echo then read response."""
    ser.write(frame)
    ser.flush()
    time.sleep(len(frame) * 10e-6)  # echo drain (10 bit/byte @1 Mbps)
    deadline = time.perf_counter() + 0.05
    buf = bytearray()
    while time.perf_counter() < deadline:
        n = ser.in_waiting
        if n:
            buf += ser.read(n)
        elif buf:
            break  # silence = response end
    return bytes(buf) or None


def tx(ser, args, frame: bytes) -> bytes | None:
    transact = mcu_transact if args.via == "mcu" else raw_transact
    resp = transact(ser, frame)
    if resp is None:
        return None
    try:
        return sp.parse_response(resp)
    except sp.ProtocolError as exc:
        print(f"  ! bad response ({len(resp)}B): {exc}")
        return None


def main() -> int:
    ap = argparse.ArgumentParser(description="single-servo swing test")
    ap.add_argument("--port", required=True, help="COMx / /dev/ttyACM0")
    ap.add_argument("--id", type=int, default=1, help="servo id (default 1)")
    ap.add_argument("--via", choices=["mcu", "raw"], default="mcu")
    ap.add_argument("--swings", type=int, default=3)
    args = ap.parse_args()

    baud = 115200 if args.via == "mcu" else 1000000
    ser = open_port(args.port, baud)
    print(f"[1/4] PING servo {args.id} ...")
    r = tx(ser, args, sp.build_ping(args.id))
    if r is None:
        print("  FAIL: no response. check: common GND / 5V supply / DATA wire / ID")
        return 1
    print(f"  OK: model={r.data.hex()} -> servo online")

    print("[2/4] torque on ...")
    tx(ser, args, sp.build_write(args.id, sp.Reg.TORQUE_SWITCH[0], bytes([1])))

    print(f"[3/4] swing x{args.swings} (mid={MID} <-> mid+60deg, speed={SWEEP_SPEED})")
    try:
        for i in range(args.swings):
            for target in (MID + SWING, MID):
                tx(ser, args, sp.build_write_u16(args.id, sp.Reg.RUNNING_SPEED[0], SWEEP_SPEED))
                tx(ser, args, sp.build_write_u16(args.id, sp.Reg.GOAL_POSITION[0], target))
                time.sleep(1.2)
            print(f"  swing {i + 1}/{args.swings} done")
    except KeyboardInterrupt:
        pass

    print("[4/4] torque off (center) ...")
    tx(ser, args, sp.build_write_u16(args.id, sp.Reg.GOAL_POSITION[0], MID))
    time.sleep(1.0)
    tx(ser, args, sp.build_write(args.id, sp.Reg.TORQUE_SWITCH[0], bytes([2])))
    ser.close()
    print("DONE. control chain verified -> next: probe_servos.py for all 8 IDs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
