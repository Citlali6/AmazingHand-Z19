from dataclasses import replace
import json
import threading
import time

import numpy as np
import pytest

from visiongrasp.app.controller import DemoController
from visiongrasp.app.ui import Dashboard
from visiongrasp.contracts import (
    FramePacket, RobotFeedback, RobotSource, StageStatus, StageResult,
    VisionSource, VisionTarget,
)


class BlockingRobot:
    robot_source = RobotSource.FAKE

    def __init__(self, status=StageStatus.DRY_RUN, blocked=False):
        self.status = status
        self.entered = threading.Event()
        self.release = threading.Event()
        if not blocked:
            self.release.set()
        self.calls = []
        self.stopped = False

    def begin_run(self, session):
        self.stopped = False

    def send_stage(self, request):
        self.calls.append(request)
        self.entered.set()
        assert self.release.wait(1)
        now = time.monotonic()
        return StageResult(request.run_session, request.sequence, request.stage.value,
                           self.status, now, now, "SIMULATED_FAILURE" if self.status != StageStatus.DRY_RUN else None)

    def query_feedback(self):
        return RobotFeedback(RobotSource.FAKE, time.monotonic(), None, None, True)

    def cancel_future_stages(self):
        self.stopped = True
        self.release.set()

    def close(self):
        self.stopped = True


def observation(*, age=0, calibration="table-1", source=VisionSource.SYNTHETIC, center=(50., 60.)):
    now = time.monotonic() - age
    packet = FramePacket(np.zeros((100, 200, 3), np.uint8), "camera-1", 1, now, source, (200, 100))
    target = VisionTarget(packet.camera_session, packet.frame_id, now, source, packet.frame_wh_px,
                          "red_block", center, (10., 20.) if calibration else None,
                          calibration, bool(calibration), None if calibration else "UNCALIBRATED",
                          .9, (40, 50, 20, 20))
    return packet, target


def prepared(tmp_path, robot=None, **observation_args):
    robot = robot or BlockingRobot()
    c = DemoController(robot, tmp_path)
    frame, target = observation(**observation_args)
    c.observe(frame, [target])
    c.select(0)
    return c, robot


def test_complete_sequence_log_never_claims_physical_coordinates(tmp_path):
    c, robot = prepared(tmp_path)
    assert c.start(operator_confirmed=True)
    assert c.wait()
    assert len(robot.calls) == 7
    assert all(r.robot_xyz_mm is None and not r.motion_allowed for r in robot.calls)
    assert c.snapshot()["completed_stages"] == 7
    rows = [json.loads(line) for line in c.log.path.read_text().splitlines()]
    assert any(row["event"] == "MOCK_SEQUENCE_COMPLETED" for row in rows)
    assert all(row["robot_source"] == "FAKE" and row["robot_xyz_mm"] is None for row in rows)
    c.close()


@pytest.mark.parametrize("case, expected", [("stale", "STALE_FRAME"),
    ("uncalibrated", "UNCALIBRATED"), ("unconfirmed", "OPERATOR_NOT_CONFIRMED"),
    ("no_target", "NO_SELECTED_TARGET"), ("no_frame", "NO_FRAME")])
def test_invalid_inputs_never_send(tmp_path, case, expected):
    c, robot = prepared(tmp_path, age=2 if case == "stale" else 0,
                        calibration=None if case == "uncalibrated" else "table-1")
    if case == "no_target":
        frame, _ = observation()
        c.observe(frame, [])
    if case == "no_frame":
        c.observe(None, [])
    assert not c.start(operator_confirmed=case != "unconfirmed")
    assert c.error == expected
    assert not robot.calls
    c.close()


@pytest.mark.parametrize("trigger", ["operator", "disconnect", "moved", "calibration_changed"])
def test_cancellation_prevents_following_stage(tmp_path, trigger):
    c, robot = prepared(tmp_path, BlockingRobot(blocked=True))
    assert c.start(operator_confirmed=True)
    assert robot.entered.wait(1)
    if trigger == "operator":
        c.stop()
    elif trigger == "disconnect":
        c.observe(None, [])
    else:
        frame, target = observation(center=(100., 60.) if trigger == "moved" else (50., 60.),
                                    calibration="changed" if trigger == "calibration_changed" else "table-1")
        c.observe(frame, [target])
    assert c.wait()
    assert len(robot.calls) == 1
    assert c.status.value == "STOP_REQUESTED"
    c.close()


def test_double_click_does_not_duplicate_execution(tmp_path):
    c, robot = prepared(tmp_path, BlockingRobot(blocked=True))
    assert c.start(operator_confirmed=True)
    assert robot.entered.wait(1)
    assert not c.start(operator_confirmed=True)
    robot.release.set()
    assert c.wait()
    assert len(robot.calls) == 7
    c.close()


@pytest.mark.parametrize("status", [StageStatus.SENT, StageStatus.TIMED_OUT, StageStatus.FAULT])
def test_sent_is_not_fake_completion(tmp_path, status):
    c, robot = prepared(tmp_path, BlockingRobot(status=status))
    assert c.start(operator_confirmed=True)
    assert c.wait()
    assert len(robot.calls) == 1
    assert c.status.value == "FAULT"
    assert c.snapshot()["completed_stages"] == 0
    c.close()


def test_targets_from_other_frame_are_not_selectable(tmp_path):
    c = DemoController(BlockingRobot(), tmp_path)
    frame, target = observation()
    c.observe(frame, [replace(target, frame_id=2)])
    assert not c.select(0)
    c.close()


def test_real_robot_is_rejected_before_any_query(tmp_path):
    class Real:
        robot_source = RobotSource.ROARM_SERIAL
        def query_feedback(self):
            pytest.fail("real robot queried")
    with pytest.raises(ValueError, match="FAKE"):
        DemoController(Real(), tmp_path)


def test_feedback_wait_does_not_block_snapshot_or_stop(tmp_path):
    class SlowFeedback(BlockingRobot):
        def __init__(self):
            super().__init__()
            self.feedback_entered = threading.Event()
            self.feedback_release = threading.Event()
        def query_feedback(self):
            self.feedback_entered.set()
            assert self.feedback_release.wait(1)
            return super().query_feedback()
        def cancel_future_stages(self):
            super().cancel_future_stages()
            self.feedback_release.set()
    c, robot = prepared(tmp_path, SlowFeedback())
    assert c.start(operator_confirmed=True)
    assert robot.feedback_entered.wait(1)
    started = time.monotonic()
    assert c.snapshot()["completed_stages"] == 0
    c.stop()
    assert time.monotonic() - started < .2
    assert c.wait()
    assert len(robot.calls) == 1
    assert c.snapshot()["completed_stages"] == 0
    c.close()


def test_beginning_calibration_invalidates_previous_selection(tmp_path):
    c, robot = prepared(tmp_path)
    c.invalidate_selection()
    assert c.selected is None
    assert not c.start(operator_confirmed=True)
    assert not robot.calls
    c.close()


def test_dashboard_can_render_without_gui(tmp_path):
    c, _ = prepared(tmp_path)
    packet, target = observation()
    dashboard = Dashboard()
    image = dashboard.render(packet, [target], c.snapshot())
    assert image.shape == (800, 1280, 3)
    assert dashboard.action(900, 180) == "run"
    assert dashboard.image_point(30, 125) is not None
    c.close()
