"""Transport tests patch serial.Serial with an in-memory class, never a port."""
from dataclasses import replace
import json
import math
import time
from types import SimpleNamespace

import pytest
import serial

from visiongrasp.contracts import ActionRequest, Stage, StageStatus
from visiongrasp.robot import BenchSafety, RoArmSerialRobot
from visiongrasp.robot.serial import _sdk_factory


class MemoryPort:
    mode = "ok"
    instances = []

    def __init__(self):
        self.writes = []
        self.rx = bytearray()
        self.is_open = False
        self.write_timeout = None
        self.instances.append(self)

    def open(self):
        self.is_open = True

    def close(self):
        self.is_open = False

    def reset_input_buffer(self):
        self.rx.clear()

    def write(self, command):
        self.writes.append(json.loads(command))
        if self.mode == "short":
            return len(command) - 1
        if self.mode == "timeout":
            raise serial.SerialTimeoutException("mock")
        if self.mode == "disconnect":
            raise serial.SerialException("mock")
        if json.loads(command)["T"] == 105 and self.mode != "missing":
            feedback = {"T": 1051, "x": 100, "y": 0, "z": 100,
                        "b": 0, "s": 0, "e": math.pi / 2, "t": math.pi - math.pi / 4}
            self.rx.extend(json.dumps(feedback).encode() + b"\r\n")
        return len(command)

    @property
    def in_waiting(self):
        return len(self.rx)

    def read(self, size):
        data = bytes(self.rx[:size])
        del self.rx[:size]
        return data


@pytest.fixture
def memory_serial(monkeypatch):
    MemoryPort.mode = "ok"
    MemoryPort.instances = []
    monkeypatch.setattr(serial, "Serial", MemoryPort)
    yield MemoryPort
    for instance in MemoryPort.instances:
        assert not instance.is_open, "test must close its mock connection"


def measured_mock_safety():
    # Synthetic test data. NEVER exported as a real workspace configuration.
    return BenchSafety("test-only", ((50, 150), (-50, 50), (50, 150)), (10, 80),
                       50, 5, True, True, True, True)


def make_robot(**kwargs):
    return RoArmSerialRobot(mode="real", port="MEMORY-NOT-COM", onsite_confirmed=True,
                            safety=measured_mock_safety(), **kwargs)


def gripper_request(**kwargs):
    return ActionRequest("test", 2, Stage.GRIP, robot_xyz_mm=(100, 0, 100),
                         gripper_target_deg=45, speed_setting=10, acceleration_setting=2,
                         operator_confirmed=True, calibration_id="test-only", motion_allowed=True, **kwargs)


def test_default_disconnected_and_never_constructs_sdk():
    calls = []
    robot = RoArmSerialRobot(sdk_factory=lambda **kw: calls.append(kw))
    assert robot.query_feedback().error == "DISCONNECTED"
    with pytest.raises(PermissionError):
        robot.connect()
    assert not calls
    robot.close()


@pytest.mark.parametrize("mode,port,confirmation", [("mock", "MEMORY", True), ("real", None, True), ("real", "MEMORY", False)])
def test_connection_requires_all_physical_gates(mode, port, confirmation):
    calls = []
    robot = RoArmSerialRobot(mode=mode, port=port, onsite_confirmed=confirmation,
                            sdk_factory=lambda **kw: calls.append(kw))
    with pytest.raises(PermissionError):
        robot.connect()
    assert calls == []
    robot.close()


def test_real_sdk_in_memory_query_units_and_exclusivity(memory_serial):
    robot = make_robot()
    other = make_robot()
    try:
        robot.connect()
        port = memory_serial.instances[0]
        assert port.write_timeout == 0.1
        assert port.baudrate == 115200
        with pytest.raises(RuntimeError, match="PORT_ALREADY_OWNED"):
            other.connect()
        feedback = robot.query_feedback()
        assert feedback.communication_ok
        assert feedback.end_xyz_mm == (100, 0, 100)
        assert feedback.joint_angles_deg == pytest.approx((0, 0, 90, 45))
        assert port.writes == [{"T": 105}]
        robot.close()
        other.connect()
    finally:
        robot.close()
        other.close()


@pytest.mark.parametrize("mode", ["short", "timeout", "disconnect", "missing"])
def test_stock_sdk_retry_layer_is_bypassed_once_and_failure_latches(memory_serial, mode):
    robot = make_robot()
    try:
        robot.connect()
        memory_serial.mode = mode
        assert not robot.query_feedback().communication_ok
        assert len(memory_serial.instances[0].writes) == 1
        assert not robot.query_feedback().communication_ok
        assert len(memory_serial.instances[0].writes) == 1
        with pytest.raises(RuntimeError, match="RECREATE"):
            robot.connect()
    finally:
        robot.close()


@pytest.mark.parametrize("raw", [None, -1, b"sent", [0] * 6, [0] * 8,
                                    [1, 2, 3, 0, 0, 0, float("nan")],
                                    [1, 2, 3, 0, 0, 0, math.pi]])
def test_invalid_sdk_feedback_fails_closed(raw):
    port = SimpleNamespace(close=lambda: None, write_timeout=None)
    sdk = SimpleNamespace(_serial_port=port, feedback_get=lambda: raw)
    robot = make_robot(sdk_factory=lambda **kw: sdk)
    try:
        robot.connect()
        feedback = robot.query_feedback()
        assert not feedback.communication_ok
        assert feedback.end_xyz_mm is feedback.joint_angles_deg is None
        assert feedback.error == "INVALID_OR_MISSING_FEEDBACK"
    finally:
        robot.close()


def test_unmeasured_workspace_and_cartesian_no_speed_are_rejected(memory_serial):
    robot = make_robot()
    try:
        robot.connect()
        robot.begin_run("test")
        assert robot.query_feedback().communication_ok
        req = replace(gripper_request(), sequence=0, stage=Stage.PREPARE)
        robot.safety = None
        assert robot.send_stage(req).error == "MEASURED_WORKSPACE_REQUIRED"
        robot.safety = measured_mock_safety()
        assert robot.send_stage(req).error == "CARTESIAN_SPEED_UNVERIFIED"
        assert memory_serial.instances[0].writes == [{"T": 105}]
        assert robot.send_stage(replace(req, motion_allowed=False)).error == "MOTION_NOT_AUTHORIZED"
        assert robot.send_stage(replace(req, robot_xyz_mm=(1000, 0, 100))).error == "OUT_OF_WORKSPACE"
        assert robot.send_stage(replace(req, calibration_id="wrong")).error == "CALIBRATION_MISMATCH"
        assert robot.send_stage(replace(req, speed_setting=10.5)).error == "INTEGER_SPEED_REQUIRED"
        assert robot.send_stage(replace(req, speed_setting=100)).error == "SPEED_OUT_OF_RANGE"
        assert robot.send_stage(replace(req, acceleration_setting=9)).error == "ACCELERATION_OUT_OF_RANGE"
        assert robot.send_stage(replace(req, gripper_target_deg=89)).error == "GRIPPER_OUT_OF_RANGE"
    finally:
        robot.close()


def test_lowlevel_gripper_result_is_not_hidden_by_vendor_wrapper(memory_serial):
    # Exercise internal gripper primitive directly; the public seven-stage
    # entrypoint remains blocked at PREPARE, pending measured Cartesian policy.
    robot = make_robot()
    try:
        robot.connect()
        assert robot.query_feedback().communication_ok
        assert robot._validate_device(gripper_request()) is None
        result = robot._perform(gripper_request(), time.monotonic())
        assert result.status is StageStatus.FEEDBACK_CONFIRMED
        port = memory_serial.instances[0]
        assert [cmd["T"] for cmd in port.writes] == [105, 121, 105, 105]
        assert port.writes[1] == {"T": 121, "joint": 4, "angle": 135,
                                  "spd": 10 * 180 / 2048, "acc": 2 * 180 / (254 * 100)}
        assert robot.history[0].status is StageStatus.SENT
        assert robot.history[0].completed_monotonic_s is None
    finally:
        robot.close()


@pytest.mark.parametrize("mode,status,error", [
    ("missing", StageStatus.FAULT, "INVALID_OR_MISSING_FEEDBACK"),
    ("short", StageStatus.FAULT, "ADAPTER_EXCEPTION"),
])
def test_sending_bytes_never_implies_completion(memory_serial, mode, status, error):
    robot = make_robot()
    try:
        robot.connect()
        assert robot.query_feedback().communication_ok
        # Use send_stage with only the stage-order gate isolated. No physical I/O
        # is reachable: all communication here uses MemoryPort.
        robot.begin_run("test")
        robot._stage_index = 2
        memory_serial.mode = mode
        req = replace(gripper_request(), sequence=0)
        result = robot.send_stage(req)
        assert result.status is status
        assert result.error == error
        assert sum(cmd["T"] == 121 for cmd in memory_serial.instances[0].writes) == 1
        assert robot.send_stage(req).status is StageStatus.REJECTED
        with pytest.raises(RuntimeError, match="RECONNECT"):
            robot.begin_run("replay")
        if mode == "missing":
            assert any(r.status is StageStatus.SENT for r in robot.history)
        assert not any(r.status is StageStatus.FEEDBACK_CONFIRMED for r in robot.history)
    finally:
        robot.close()


def test_valid_feedback_but_never_reaches_target_times_out_without_motion_retry(memory_serial):
    robot = make_robot()
    try:
        robot.connect()
        assert robot.query_feedback().communication_ok
        robot.begin_run("test")
        robot._stage_index = 2
        req = replace(gripper_request(timeout_s=0.05), sequence=0, gripper_target_deg=50)
        result = robot.send_stage(req)
        assert result.status is StageStatus.TIMED_OUT
        assert result.error == "FEEDBACK_NOT_AT_TARGET"
        assert sum(cmd["T"] == 121 for cmd in memory_serial.instances[0].writes) == 1
    finally:
        robot.close()


def test_connect_failure_releases_reservation_and_does_not_retry():
    calls = []
    def fail(**kwargs):
        calls.append(kwargs)
        raise OSError("synthetic occupied port")
    robot = make_robot(sdk_factory=fail)
    with pytest.raises(RuntimeError, match="CONNECT_FAILED"):
        robot.connect()
    with pytest.raises(RuntimeError, match="RECREATE"):
        robot.connect()
    assert len(calls) == 1
    assert "memory-not-com" not in RoArmSerialRobot._ports
    robot.close()
