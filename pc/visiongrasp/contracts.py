"""Shared PC v0.1 contracts. Units are explicit; unavailable measurements are None."""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
import math
import time
from typing import Any


class VisionSource(str, Enum):
    LIVE_PC_UVC = "LIVE_PC_UVC"
    IMAGE_TEST = "IMAGE_TEST"
    SYNTHETIC = "SYNTHETIC"


class RobotSource(str, Enum):
    FAKE = "FAKE"
    ROARM_SERIAL = "ROARM_SERIAL"
    UNKNOWN = "UNKNOWN"


class Stage(str, Enum):
    QUERY = "QUERY"
    PREPARE = "PREPARE"
    APPROACH = "APPROACH"
    GRIP = "GRIP"
    LIFT = "LIFT"
    TRANSFER = "TRANSFER"
    RELEASE = "RELEASE"
    RETURN = "RETURN"


MOTION_STAGES = tuple(stage for stage in Stage if stage is not Stage.QUERY)


class StageStatus(str, Enum):
    DRY_RUN = "DRY_RUN"
    SENT = "SENT"
    FEEDBACK_CONFIRMED = "FEEDBACK_CONFIRMED"
    TIMED_OUT = "TIMED_OUT"
    REJECTED = "REJECTED"
    FAULT = "FAULT"


class CameraStatus(str, Enum):
    CAMERA_OK = "CAMERA_OK"
    NO_FRAME = "NO_FRAME"
    UNCALIBRATED = "UNCALIBRATED"


class RobotStatus(str, Enum):
    ROBOT_MOCK = "ROBOT_MOCK"
    ROBOT_CONNECTED = "ROBOT_CONNECTED"
    FAULT = "FAULT"


class TaskStatus(str, Enum):
    IDLE = "IDLE"
    RUNNING = "RUNNING"
    STOP_REQUESTED = "STOP_REQUESTED"
    FAULT = "FAULT"


def finite(value: Any, name: str, *, positive: bool = False) -> None:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    if positive and value <= 0:
        raise ValueError(f"{name} must be positive")


def vector(value: Any, length: int, name: str) -> None:
    if not isinstance(value, tuple) or len(value) != length:
        raise ValueError(f"{name} must be a {length}-tuple")
    for entry in value:
        finite(entry, name)


def identity(session: str, sequence: int) -> None:
    if not isinstance(session, str) or not session.strip():
        raise ValueError("session must not be empty")
    if type(sequence) is not int or sequence < 0:
        raise ValueError("sequence must be a nonnegative integer")


def enum_value(value: Any, kind: type[Enum]) -> None:
    if not isinstance(value, kind):
        raise ValueError(f"expected {kind.__name__}, got {value!r}")


def frame_metadata(session: str, frame_id: int, timestamp: float, source: VisionSource, size: tuple[int, int]) -> None:
    identity(session, frame_id)
    finite(timestamp, "capture_monotonic_s")
    if timestamp < 0:
        raise ValueError("capture timestamp must be nonnegative")
    enum_value(source, VisionSource)
    vector(size, 2, "frame_wh_px")
    if any(type(n) is not int or n <= 0 for n in size):
        raise ValueError("frame dimensions must be positive integers")


@dataclass(frozen=True)
class FramePacket:
    image: Any
    camera_session: str
    frame_id: int
    capture_monotonic_s: float
    source: VisionSource
    frame_wh_px: tuple[int, int]

    def __post_init__(self) -> None:
        frame_metadata(self.camera_session, self.frame_id, self.capture_monotonic_s, self.source, self.frame_wh_px)
        w, h = self.frame_wh_px
        if getattr(self.image, "shape", None) != (h, w, 3) or str(getattr(self.image, "dtype", "")) != "uint8":
            raise ValueError("image must be uint8 BGR matching frame_wh_px")


@dataclass(frozen=True)
class VisionTarget:
    camera_session: str
    frame_id: int
    capture_monotonic_s: float
    source: VisionSource
    frame_wh_px: tuple[int, int]
    object_label: str
    center_uv_px: tuple[float, float]
    table_xy_mm: tuple[float, float] | None
    calibration_id: str | None
    valid: bool
    rejected_reason: str | None
    confidence_or_rule_score: float | None = None
    bbox_xywh_px: tuple[int, int, int, int] | None = None

    def __post_init__(self) -> None:
        frame_metadata(self.camera_session, self.frame_id, self.capture_monotonic_s, self.source, self.frame_wh_px)
        vector(self.center_uv_px, 2, "center_uv_px")
        if not self.object_label or type(self.valid) is not bool:
            raise ValueError("label and validity required")
        if self.table_xy_mm is not None:
            vector(self.table_xy_mm, 2, "table_xy_mm")
        if self.valid and (self.table_xy_mm is None or not self.calibration_id or self.rejected_reason):
            raise ValueError("valid target requires calibrated table coordinates and no rejection")
        if not self.valid and not self.rejected_reason:
            raise ValueError("invalid target requires a reason")
        if self.confidence_or_rule_score is not None:
            finite(self.confidence_or_rule_score, "rule score")
            if not 0 <= self.confidence_or_rule_score <= 1:
                raise ValueError("rule score outside [0,1]")
        if self.bbox_xywh_px is not None:
            vector(self.bbox_xywh_px, 4, "bbox_xywh_px")


@dataclass(frozen=True)
class RobotFeedback:
    robot_source: RobotSource
    received_monotonic_s: float
    joint_angles_deg: tuple[float, ...] | None
    end_xyz_mm: tuple[float, float, float] | None
    communication_ok: bool
    raw_feedback_summary: str | None = None
    error: str | None = None

    def __post_init__(self) -> None:
        enum_value(self.robot_source, RobotSource)
        finite(self.received_monotonic_s, "received_monotonic_s")
        if type(self.communication_ok) is not bool:
            raise ValueError("communication_ok must be bool")
        if self.joint_angles_deg is not None:
            vector(self.joint_angles_deg, 4, "joint_angles_deg")
        if self.end_xyz_mm is not None:
            vector(self.end_xyz_mm, 3, "end_xyz_mm")


@dataclass(frozen=True)
class ActionRequest:
    run_session: str
    sequence: int
    stage: Stage
    robot_xyz_mm: tuple[float, float, float] | None = None
    gripper_target_deg: float | None = None
    speed_setting: float | None = None
    acceleration_setting: float | None = None
    operator_confirmed: bool = False
    calibration_id: str | None = None
    motion_allowed: bool = False
    created_monotonic_s: float = field(default_factory=time.monotonic)
    timeout_s: float = 2.0

    def __post_init__(self) -> None:
        identity(self.run_session, self.sequence)
        enum_value(self.stage, Stage)
        if self.robot_xyz_mm is not None:
            vector(self.robot_xyz_mm, 3, "robot_xyz_mm")
        for name in ("gripper_target_deg", "speed_setting", "acceleration_setting"):
            value = getattr(self, name)
            if value is not None:
                finite(value, name, positive=name != "gripper_target_deg")
        finite(self.created_monotonic_s, "created_monotonic_s")
        finite(self.timeout_s, "timeout_s", positive=True)
        if type(self.operator_confirmed) is not bool or type(self.motion_allowed) is not bool:
            raise ValueError("confirmation and permission must be bool")


@dataclass(frozen=True)
class StageResult:
    run_session: str
    sequence: int
    stage: str
    status: StageStatus
    started_monotonic_s: float
    completed_monotonic_s: float | None = None
    error: str | None = None

    def __post_init__(self) -> None:
        identity(self.run_session, self.sequence)
        if self.stage not in {s.value for s in Stage}:
            raise ValueError("invalid stage")
        enum_value(self.status, StageStatus)
        finite(self.started_monotonic_s, "started_monotonic_s")
        if self.completed_monotonic_s is not None:
            finite(self.completed_monotonic_s, "completed_monotonic_s")
            if self.completed_monotonic_s < self.started_monotonic_s:
                raise ValueError("completion before start")


@dataclass(frozen=True)
class SystemStatus:
    camera: CameraStatus = CameraStatus.NO_FRAME
    robot: RobotStatus = RobotStatus.ROBOT_MOCK
    task: TaskStatus = TaskStatus.IDLE

    def __post_init__(self) -> None:
        enum_value(self.camera, CameraStatus)
        enum_value(self.robot, RobotStatus)
        enum_value(self.task, TaskStatus)
