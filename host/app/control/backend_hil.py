"""PC side of amazinghand-hil/1. PL telemetry alone controls the MuJoCo plant.

There is deliberately no software-FSM fallback when the board is unavailable.
"""
from __future__ import annotations

import json
import logging
import socket

from app.control import scs_protocol as sp
from app.control.mujoco_plant import MujocoPlant

PROTOCOL = "amazinghand-hil/1"
STATES = ("IDLE", "PREGRASP", "CLOSING", "HOLD", "RELEASING", "PROTECT")


def validate_reply(reply, seq=None):
    if not isinstance(reply, dict) or reply.get("protocol") != PROTOCOL or reply.get("source") != "pl":
        raise ValueError("matching PL protocol/source required; no simulator fallback")
    for field in ("seq", "accepted_seq", "feedback_seq", "fault", "pl_tick",
                  "command_count", "feedback_count"):
        if type(reply.get(field)) is not int or not 0 <= reply[field] <= 0xFFFFFFFF:
            raise ValueError(f"invalid PL {field}")
    if seq is not None and any(reply[field] != seq for field in ("seq", "accepted_seq", "feedback_seq")):
        raise ValueError("PL sequence/feedback acknowledgement mismatch")
    if reply.get("state") not in STATES or type(reply.get("torque_enabled")) is not bool:
        raise ValueError("invalid PL state or torque flag")
    if (reply["fault"] or reply["state"] == "PROTECT") and reply["torque_enabled"]:
        raise ValueError("unsafe PL telemetry: torque enabled during fault")
    targets = reply.get("target_raw")
    if not isinstance(targets, list) or len(targets) != 8 or any(
            type(x) is not int or not 0 <= x <= 4095 for x in targets):
        raise ValueError("eight PL target_raw values required")
    return reply


class HilBackend:
    name = "hil"

    def __init__(self, address):
        host, port = address.rsplit(":", 1)
        self.address = host, int(port)
        self.plant = MujocoPlant()
        self.socket = self.stream = None
        self.reply = None
        self.stopped = True
        self.seq = 0
        self._target = self.plant.feedback_raw()["position_raw"]
        self._since_exchange = 0.0

    def _roundtrip(self, frame):
        if self.stream is None:
            raise RuntimeError("HIL link is not open")
        self.stream.write((json.dumps(frame, separators=(",", ":")) + "\n").encode())
        self.stream.flush()
        line = self.stream.readline(4097)
        if len(line) > 4096 or not line.endswith(b"\n"):
            raise ValueError("HIL reply missing, oversized or incomplete")
        return json.loads(line)

    def open(self):
        try:
            self.socket = socket.create_connection(self.address, timeout=0.25)
            self.stream = self.socket.makefile("rwb")
            self.reply = validate_reply(self._roundtrip({"protocol": PROTOCOL, "cmd": "hello"}))
            self.seq = self.reply["accepted_seq"]
            # Always require explicit reset for a new operator session.
            self.emergency_stop()
        except BaseException:
            self.close()
            raise

    def _exchange(self, cmd):
        self.seq += 1
        try:
            self.reply = validate_reply(self._roundtrip({
                "protocol": PROTOCOL, "seq": self.seq, "heartbeat": self.seq,
                "cmd": cmd, "target_raw": self._target,
                "feedback": self.plant.feedback_raw(),
            }), self.seq)
            self.stopped = self.reply["state"] == "PROTECT" or bool(self.reply["fault"])
            self.plant.apply_raw_targets(self.reply["target_raw"], self.reply["torque_enabled"])
            self._since_exchange = 0
        except BaseException:
            self.stopped = True
            self.plant.disable()
            raise

    def _motion(self, cmd):
        if self.stopped:
            raise RuntimeError("PL STOP is latched; explicit reset required")
        if cmd in ("open", "grasp") and self.reply["state"] != "IDLE":
            raise RuntimeError("PL motion is active; release or reset before a new grasp/open")
        self._exchange(cmd)

    def open_hand(self):
        self._target = [sp.rad_to_raw(0.0)] * 8
        self._motion("open")

    def start_grasp_fsm(self, plan):
        import math

        self._target = [sp.rad_to_raw(math.radians(x)) for x in plan.angles_deg]
        self._motion("grasp")

    def hold(self):
        self._motion("hold")

    def release(self):
        self._motion("release")

    def reset(self):
        self._target = self.plant.feedback_raw()["position_raw"]
        self._exchange("reset")
        if self.stopped:
            raise RuntimeError("PL refused reset; inspect fault/feedback")

    def emergency_stop(self):
        try:
            if self.stream is not None:
                self._exchange("stop")
        finally:
            self.stopped = True
            self.plant.disable()

    def tick(self, dt_s):
        self._since_exchange += dt_s
        if self._since_exchange >= 0.02:
            self._exchange("tick")
        self.plant.step(dt_s)

    def close(self):
        try:
            self.emergency_stop()
        except Exception:
            logging.getLogger(__name__).exception("HIL stop unconfirmed; PL watchdog must protect")
        finally:
            try:
                if self.stream:
                    self.stream.close()
            finally:
                if self.socket:
                    self.socket.close()
                self.stream = self.socket = None
                self.plant.disable()
