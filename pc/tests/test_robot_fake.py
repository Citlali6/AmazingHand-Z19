from dataclasses import replace
import threading
import time

import pytest

from visiongrasp.contracts import ActionRequest, MOTION_STAGES, RobotSource, Stage, StageStatus
from visiongrasp.robot import FakeRobot, RobotAdapter


def request(sequence=0, stage=Stage.PREPARE, **kwargs):
    return ActionRequest("run-1", sequence, stage, operator_confirmed=True,
                         calibration_id="synthetic-table", **kwargs)


def test_seven_stages_and_unknown_physical_pose():
    robot = FakeRobot(stage_delay_s=0)
    assert isinstance(robot, RobotAdapter)
    robot.begin_run("run-1")
    for seq, stage in enumerate(MOTION_STAGES):
        assert robot.send_stage(request(seq, stage)).status is StageStatus.DRY_RUN
        feedback = robot.query_feedback()
        assert feedback.robot_source is RobotSource.FAKE
        assert feedback.end_xyz_mm is feedback.joint_angles_deg is None
    assert robot.completed_stages == list(MOTION_STAGES)
    assert robot.send_stage(request(7, Stage.PREPARE)).error == "INVALID_STAGE_ORDER"


@pytest.mark.parametrize("changes,reason", [
    ({"operator_confirmed": False}, "NOT_CONFIRMED"),
    ({"calibration_id": None}, "UNCALIBRATED"),
    ({"created_monotonic_s": time.monotonic() - 100}, "STALE_REQUEST"),
    ({"created_monotonic_s": time.monotonic() + 100}, "STALE_REQUEST"),
    ({"sequence": 1}, "SEQUENCE_REPLAY_OR_GAP"),
    ({"stage": Stage.GRIP}, "INVALID_STAGE_ORDER"),
    ({"motion_allowed": True}, "MOCK_ONLY_NO_PHYSICAL_COORDINATES"),
    ({"robot_xyz_mm": (1, 2, 3)}, "MOCK_ONLY_NO_PHYSICAL_COORDINATES"),
    ({"gripper_target_deg": 91}, "GRIPPER_OUT_OF_RANGE"),
    ({"speed_setting": 101}, "SPEED_OUT_OF_RANGE"),
    ({"acceleration_setting": 11}, "ACCELERATION_OUT_OF_RANGE"),
])
def test_guards(changes, reason):
    robot = FakeRobot(stage_delay_s=0)
    robot.begin_run("run-1")
    result = robot.send_stage(replace(request(), **changes))
    assert result.status is StageStatus.REJECTED
    assert result.error == reason
    assert not robot.completed_stages


def test_query_and_duplicates():
    robot = FakeRobot(stage_delay_s=0)
    assert robot.send_stage(request()).error == "SESSION_NOT_STARTED"
    robot.begin_run("run-1")
    assert robot.send_stage(request(stage=Stage.QUERY)).status is StageStatus.FEEDBACK_CONFIRMED
    assert robot.send_stage(request(1)).status is StageStatus.DRY_RUN
    assert robot.send_stage(request(1)).error == "SEQUENCE_REPLAY_OR_GAP"
    assert len(robot.completed_stages) == 1


def test_sticky_stop_cancellable_wait_and_explicit_new_session():
    robot = FakeRobot(stage_delay_s=5)
    robot.begin_run("run-1")
    results = []
    thread = threading.Thread(target=lambda: results.append(robot.send_stage(request(timeout_s=10))))
    thread.start()
    deadline = time.monotonic() + 1
    while not robot._running and time.monotonic() < deadline:
        time.sleep(0.001)
    assert robot._running
    robot.cancel_future_stages()
    thread.join(timeout=1)
    assert not thread.is_alive()
    assert results[0].error == "STOP_REQUESTED"
    assert not robot.completed_stages
    assert robot.send_stage(replace(request(), run_session="new")).error == "STOP_REQUESTED"
    with pytest.raises(ValueError, match="SESSION_REPLAY"):
        robot.begin_run("run-1")
    robot.begin_run("new")
    robot.stage_delay_s = 0
    assert robot.send_stage(replace(request(), run_session="new")).status is StageStatus.DRY_RUN


@pytest.mark.parametrize("options,status,error", [
    ({"timeout_stage": Stage.PREPARE}, StageStatus.TIMED_OUT, "MOCK_TIMEOUT"),
    ({"fault_stage": Stage.PREPARE}, StageStatus.FAULT, "MOCK_FAULT"),
])
def test_injected_failure_latches_until_adapter_recreated(options, status, error):
    robot = FakeRobot(stage_delay_s=0, **options)
    robot.begin_run("run-1")
    result = robot.send_stage(request(timeout_s=0.01))
    assert result.status is status
    assert result.error == error
    assert not robot.query_feedback().communication_ok
    assert robot.send_stage(request(1, Stage.APPROACH)).status is StageStatus.REJECTED
    with pytest.raises(RuntimeError, match="RECONNECT"):
        robot.begin_run("new")


def test_disconnected_and_closed():
    robot = FakeRobot(disconnected=True)
    robot.begin_run("run-1")
    assert not robot.query_feedback().communication_ok
    assert robot.send_stage(request()).error == "MOCK_DISCONNECTED"
    robot.close()
    assert robot.send_stage(request()).error == "CLOSED"
    with pytest.raises(RuntimeError, match="CLOSED"):
        robot.begin_run("new")


def test_duplicate_concurrent_calls_execute_once():
    robot = FakeRobot(stage_delay_s=0.02)
    robot.begin_run("run-1")
    result = []
    workers = [threading.Thread(target=lambda: result.append(robot.send_stage(request()))) for _ in range(2)]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join()
    assert sorted(r.status.value for r in result) == ["DRY_RUN", "REJECTED"]
    assert robot.completed_stages == [Stage.PREPARE]
