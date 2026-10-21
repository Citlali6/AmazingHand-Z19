from dataclasses import replace
import math
import pytest
import numpy as np
from visiongrasp.contracts import (
    ActionRequest, FramePacket, RobotFeedback, RobotSource, Stage, StageResult,
    StageStatus, SystemStatus, VisionSource, VisionTarget,
)


def target():
    return VisionTarget("camera", 1, 10.0, VisionSource.SYNTHETIC, (640, 480),
                        "red_block", (100.0, 120.0), (10.0, 12.0), "table-1", True, None)


def test_valid_units_and_missing_robot_coordinates():
    assert target().table_xy_mm == (10, 12)
    assert ActionRequest("run", 0, Stage.PREPARE).robot_xyz_mm is None
    assert RobotFeedback(RobotSource.FAKE, 10, None, None, True).end_xyz_mm is None
    assert SystemStatus().robot.value == "ROBOT_MOCK"
    FramePacket(np.zeros((10, 20, 3), np.uint8), "cam", 0, 10, VisionSource.SYNTHETIC, (20, 10))


@pytest.mark.parametrize("changes", [
    {"table_xy_mm": None}, {"calibration_id": None}, {"source": "LIVE_PC_UVC"},
    {"frame_id": -1}, {"frame_id": True}, {"capture_monotonic_s": math.nan},
    {"center_uv_px": (math.inf, 0)}, {"confidence_or_rule_score": 1.1},
    {"valid": False}, {"frame_wh_px": (0, 480)},
])
def test_invalid_target(changes):
    with pytest.raises(ValueError):
        replace(target(), **changes)


@pytest.mark.parametrize("changes", [
    {"sequence": -1}, {"stage": "GRIP"}, {"robot_xyz_mm": (0, 0, math.nan)},
    {"speed_setting": -1}, {"timeout_s": 0}, {"operator_confirmed": 1},
])
def test_invalid_request(changes):
    with pytest.raises(ValueError):
        replace(ActionRequest("run", 0, Stage.GRIP), **changes)


def test_invalid_measurements():
    with pytest.raises(ValueError):
        RobotFeedback(RobotSource.ROARM_SERIAL, 10, (0, 0, 0, math.nan), None, True)
    with pytest.raises(ValueError):
        StageResult("r", 0, "GRIP", StageStatus.DRY_RUN, 10, 9)
    with pytest.raises(ValueError):
        FramePacket(np.zeros((10, 20, 3), np.uint8), "cam", 0, 10, VisionSource.SYNTHETIC, (10, 20))


def test_sdk_import_has_no_serial_side_effects():
    import inspect
    from roarm_sdk.roarm import roarm
    assert inspect.signature(roarm).parameters["baudrate"].default == 115200
    for name in ("feedback_get", "pose_ctrl", "gripper_angle_ctrl"):
        assert callable(getattr(roarm, name))
