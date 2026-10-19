"""View-only PC observer for the MJC1 FPGA/PS feedback loop.

The FPGA state machine supplies the target. This process advances the upstream
AmazingHand MuJoCo model and returns measured joint positions to the FPGA.
"""
from __future__ import annotations

import argparse
import json
import math
import socket
import sys
import time
from pathlib import Path

import mujoco
import mujoco.viewer

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "AmazingHand/Demo/AHSimulation/AHSimulation/AH_Right/mjcf/scene.xml"
ACTUATORS = [f"finger{finger}_motor{motor}" for finger in range(1, 5) for motor in (1, 2)]
STATES = {0: "IDLE", 1: "PREGRASP", 2: "CLOSING", 3: "HOLD", 4: "RELEASING", 5: "PROTECT"}


class Observer:
    def __init__(self, trace: Path | None, load_gain: float):
        if not MODEL.is_file():
            raise FileNotFoundError(f"MuJoCo model missing: {MODEL}")
        self.model = mujoco.MjModel.from_xml_path(str(MODEL))
        self.data = mujoco.MjData(self.model)
        if self.model.nu != 8:
            raise RuntimeError(f"expected 8 actuators in upstream hand model, found {self.model.nu}")
        self.actuator_ids = [mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_ACTUATOR, n) for n in ACTUATORS]
        if any(i < 0 for i in self.actuator_ids):
            raise RuntimeError("upstream model actuator names do not match the MJC1 channel order")
        self.qposadr = []
        for aid in self.actuator_ids:
            jid = int(self.model.actuator_trnid[aid, 0])
            self.qposadr.append(int(self.model.jnt_qposadr[jid]))
        self.trace = trace.open("a", encoding="utf-8") if trace else None
        self.load_gain = load_gain
        self.last_state = None
        self.frames = 0

    def consume(self, msg: dict, viewer=None) -> dict:
        seq = msg.get("seq")
        state = msg.get("state")
        target = msg.get("target_raw")
        if type(seq) is not int or seq <= 0 or type(state) is not int or state not in STATES:
            raise ValueError("invalid sequence or FPGA state")
        if not isinstance(target, list) or len(target) != 8 or any(type(x) is not int or not 0 <= x <= 1800 for x in target):
            raise ValueError("target_raw must contain eight values in 0..1800")

        lo, hi = -math.pi / 2, math.pi / 2
        if viewer is not None:
            with viewer.lock():
                for i, raw in enumerate(target):
                    angle = max(lo, min(hi, math.radians((raw - 900) / 10.0)))
                    self.data.ctrl[self.actuator_ids[i]] = angle
                nstep = max(1, round(0.02 / self.model.opt.timestep))
                for _ in range(nstep):
                    mujoco.mj_step(self.model, self.data)
        else:
            for i, raw in enumerate(target):
                angle = max(lo, min(hi, math.radians((raw - 900) / 10.0)))
                self.data.ctrl[self.actuator_ids[i]] = angle
            nstep = max(1, round(0.02 / self.model.opt.timestep))
            for _ in range(nstep):
                mujoco.mj_step(self.model, self.data)
        if viewer is not None:
            viewer.sync()
        positions = [max(0, min(1800, round(math.degrees(self.data.qpos[a]) * 10 + 900))) for a in self.qposadr]
        # Virtual load is explicitly a scaled MuJoCo actuator-force indicator.
        # It is not the SCS0009 load register or calibrated physical force.
        loads = [max(0, min(1023, round(abs(float(self.data.actuator_force[a])) * self.load_gain)))
                 for a in self.actuator_ids]
        if state != self.last_state:
            print(f"FPGA FSM → {STATES[state]} | actual virtual joint angles: " +
                  ", ".join(f"{(p - 900) / 10:+.1f}°" for p in positions), flush=True)
            self.last_state = state
        self.frames += 1
        if self.trace:
            self.trace.write(json.dumps({"seq": seq, "state": STATES[state], "target_raw": target,
                                         "position_raw": positions, "load_raw": loads,
                                         "sim_time": round(float(self.data.time), 4)}) + "\n")
            self.trace.flush()
        return {"seq": seq, "position_raw": positions, "load_raw": loads,
                "sim_time": round(float(self.data.time), 4)}

    def close(self):
        if self.trace:
            self.trace.close()


def serve(client: socket.socket, observer: Observer, viewer=None):
    client.settimeout(2.0)
    pending = bytearray()
    with client:
        while viewer is None or viewer.is_running():
            while b"\n" not in pending:
                block = client.recv(4096)
                if not block:
                    return
                pending.extend(block)
                if len(pending) > 65536:
                    raise ValueError("oversized FPGA request")
            line, _, rest = pending.partition(b"\n")
            pending[:] = rest
            reply = observer.consume(json.loads(line), viewer)
            client.sendall((json.dumps(reply, separators=(",", ":")) + "\n").encode())


def main() -> int:
    ap = argparse.ArgumentParser(description="View-only MuJoCo endpoint for the FPGA MJC1 demo")
    ap.add_argument("--bind", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--headless", action="store_true", help="run without a graphics window")
    ap.add_argument("--load-gain", type=float, default=32.0)
    ap.add_argument("--trace", type=Path, help="optional JSONL trace destination")
    args = ap.parse_args()
    observer = Observer(args.trace, args.load_gain)
    print(f"MuJoCo observer ready: {MODEL}\nListening on {args.bind}:{args.port}; waiting for Z19 PS.", flush=True)
    viewer_context = mujoco.viewer.launch_passive(observer.model, observer.data) if not args.headless else None
    try:
        if viewer_context:
            with viewer_context as viewer:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
                    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    server.bind((args.bind, args.port)); server.listen(1); server.settimeout(0.5)
                    while viewer.is_running():
                        try:
                            client, address = server.accept()
                        except socket.timeout:
                            continue
                        print(f"Z19 connected from {address}; observing FPGA closed loop.", flush=True)
                        try:
                            serve(client, observer, viewer)
                        except (ValueError, OSError, json.JSONDecodeError) as exc:
                            print(f"Session ended: {exc}; viewer remains open.", flush=True)
        else:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
                server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                server.bind((args.bind, args.port)); server.listen(1)
                while True:
                    client, address = server.accept()
                    print(f"Z19 connected from {address}.", flush=True)
                    try:
                        serve(client, observer)
                    except (ValueError, OSError, json.JSONDecodeError) as exc:
                        print(f"Session ended: {exc}", flush=True)
    except KeyboardInterrupt:
        print("Observer stopped.", flush=True)
    finally:
        observer.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
