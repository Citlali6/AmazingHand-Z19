"""Existing protocol/FSM with MuJoCo dynamics and measured feedback (Issue #10)."""
from __future__ import annotations

import math

from app.control.backend_sim import SimBackend
from app.control.mujoco_plant import MujocoPlant
from app.control.scs_sim import VirtualServoBus
from app.control.servo_base import FsmState


class MujocoServoBus(VirtualServoBus):
    def __init__(self, plant):
        super().__init__()
        self.plant = plant
        self._update_feedback()

    def _update_feedback(self):
        feedback = self.plant.feedback_raw()
        for i, sid in enumerate(self.servo_ids):
            state = self.state(sid)
            state.position_raw = feedback["position_raw"][i]
            state.load_raw = feedback["load_raw"][i]

    def step(self, dt_s):
        states = [self.state(sid) for sid in self.servo_ids]
        self.plant.apply_raw_targets([s.goal_raw for s in states],
                                     [s.torque_on for s in states],
                                     [s.goal_speed_raw for s in states])
        self.plant.step(dt_s)
        self._update_feedback()


class MujocoBackend(SimBackend):
    name = "mujoco"

    def __init__(self):
        super().__init__(middle_deg=(0.0,) * 8)
        self.plant = MujocoPlant()
        self.bus = MujocoServoBus(self.plant)
        self.stopped = False
        self._discard_old_targets()

    def _discard_old_targets(self):
        for sid in self.bus.servo_ids:
            state = self.bus.state(sid)
            state.goal_raw = state.position_raw
        self._plan = None
        self._closing_hold_raw = None

    def _check_enabled(self):
        if self.stopped:
            raise RuntimeError("STOP is latched; explicit reset required")

    def set_torque(self, on):
        if on:
            self._check_enabled()
        super().set_torque(on)
        if not on:
            # A dropped virtual servo ignores protocol writes. The simulator's
            # local stop still owns its actuator enable; do not re-enable it
            # from a stale virtual torque bit on the next physics step.
            for sid in self.bus.servo_ids:
                self.bus.state(sid).torque_on = False
            self.plant.disable()

    def set_targets(self, angles_deg, speed_raw=0):
        self._check_enabled()
        if len(angles_deg) != 8 or any(not math.isfinite(x) for x in angles_deg):
            raise ValueError("need eight finite target angles")
        super().set_targets(angles_deg, speed_raw)

    def start_grasp_fsm(self, plan):
        self._check_enabled()
        super().start_grasp_fsm(plan)

    def open_hand(self):
        self._check_enabled()
        self._discard_old_targets()
        self._enter(FsmState.IDLE)
        self.set_torque(True)
        self.set_targets((0.0,) * 8, speed_raw=3)

    def hold(self):
        self._check_enabled()
        self._closing_hold_raw = tuple(f.position_raw for f in self._read_feedback())
        self.set_targets(tuple(f.position_deg for f in self._read_feedback()))
        self._enter(FsmState.HOLD)

    def release(self):
        self._check_enabled()
        # Existing backend only accepts release from CLOSING/HOLD. A user may
        # release during PREGRASP or manual opening too; cancel safely to zero.
        if self._fsm in (FsmState.CLOSING, FsmState.HOLD) and self._plan is not None:
            super().release()
        else:
            self.open_hand()

    def emergency_stop(self):
        self.stopped = True
        super().emergency_stop()
        self._discard_old_targets()

    def reset(self):
        # Remain unpowered until the next explicit motion; never replay targets.
        self.plant.disable()
        self._discard_old_targets()
        self.stopped = False
        self._closed_by_timeout = False
        self._enter(FsmState.IDLE)

    def tick(self, dt_s):
        try:
            # Catch faults before the inherited FSM can submit another target.
            if any(s.dropped or s.error_bits for s in
                   (self.bus.state(i) for i in self.bus.servo_ids)):
                self.emergency_stop()
            super().tick(dt_s)
            if self._fsm == FsmState.PROTECT:
                self.stopped = True
        except BaseException:
            self.emergency_stop()
            raise

    def close(self):
        self.emergency_stop()
