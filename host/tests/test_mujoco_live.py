"""Issue #10: actual MuJoCo feedback, live changes, hold and latched stop."""
from __future__ import annotations

import math
from pathlib import Path
import sys
import unittest

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "host"))
from sim.host_demo import LiveController
from app.control.backend_mujoco import MujocoBackend
from app.control.servo_base import FsmState


class LiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.backend = MujocoBackend()

    def setUp(self):
        self.backend.reset()
        self.controller = LiveController(self.backend)
        self.backend.open_hand()
        for _ in range(250):
            self.backend.tick(0.01)

    def tearDown(self):
        self.backend.close()

    def advance(self, seconds):
        for _ in range(round(seconds / 0.01)):
            self.controller.tick(0.01)

    def test_live_grasp_hold_release_and_measured_feedback(self):
        start = self.backend.plant.positions_rad
        self.assertTrue(self.controller.command("grasp", "apple"))
        self.advance(1.0)
        closed = self.backend.plant.positions_rad
        self.assertGreater(np.max(np.abs(closed - start)), math.radians(10))
        state = self.controller.telemetry()
        np.testing.assert_allclose(state["positions_deg"], np.degrees(closed))
        self.assertTrue(self.controller.command("hold"))
        self.advance(0.4)
        held = self.backend.plant.positions_rad
        self.advance(0.5)
        self.assertLess(np.max(np.abs(self.backend.plant.positions_rad - held)), math.radians(1))
        self.assertTrue(self.controller.command("release"))
        self.advance(2.0)
        self.assertLess(np.max(np.abs(self.backend.plant.positions_rad)), math.radians(1))
        self.assertEqual(self.backend.poll_fsm().state, FsmState.IDLE)

    def test_new_input_changes_targets_and_joint_motion_online(self):
        self.controller.command("grasp", "banana")
        self.advance(0.8)
        first = self.controller.telemetry()
        self.controller.command("grasp", "bottle")
        self.advance(0.8)
        second = self.controller.telemetry()
        self.assertNotEqual(first["target_raw"], second["target_raw"])
        self.assertFalse(np.allclose(first["positions_deg"], second["positions_deg"], atol=1))

    def test_stop_zeroes_actuation_freezes_old_goal_until_explicit_reset(self):
        self.controller.command("grasp", "banana")
        self.advance(0.6)
        self.controller.command("stop")
        stopped = self.backend.plant.positions_rad
        for action in ("open", "grasp", "hold", "release"):
            self.assertFalse(self.controller.command(action))
        self.advance(0.5)
        np.testing.assert_array_equal(self.backend.plant.positions_rad, stopped)
        np.testing.assert_array_equal(self.backend.plant.data.actuator_force, np.zeros(8))
        self.assertEqual(self.backend.poll_fsm().state, FsmState.PROTECT)
        self.assertTrue(self.controller.command("reset"))
        self.advance(0.2)
        np.testing.assert_array_equal(self.backend.plant.positions_rad, stopped)
        self.controller.command("open")
        self.advance(2.0)
        self.assertLess(np.max(np.abs(self.backend.plant.positions_rad)), math.radians(1))

    def test_invalid_physics_step_stops_before_propagating_error(self):
        self.controller.command("grasp")
        with self.assertRaises(ValueError):
            self.controller.tick(float("nan"))
        self.assertTrue(self.backend.stopped)
        np.testing.assert_array_equal(self.backend.plant.data.actuator_force, np.zeros(8))

    def test_offline_feedback_stops_during_closing(self):
        self.controller.command("grasp")
        self.advance(0.5)
        self.backend.bus.inject_drop([1])
        try:
            self.controller.tick(0.01)
            self.assertTrue(self.backend.stopped)
            self.assertEqual(self.backend.poll_fsm().state, FsmState.PROTECT)
            stopped = self.backend.plant.positions_rad
            self.advance(0.2)
            np.testing.assert_array_equal(self.backend.plant.positions_rad, stopped)
            np.testing.assert_array_equal(self.backend.plant.data.actuator_force, np.zeros(8))
            self.assertFalse(any(self.backend.bus.state(i).torque_on for i in range(1, 9)))
        finally:
            self.backend.bus.inject_drop([1], False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
