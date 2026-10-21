"""Deterministic logical mock. It never invents physical coordinates."""
from __future__ import annotations

import math
import time

from ..contracts import ActionRequest, RobotFeedback, RobotSource, Stage, StageResult, StageStatus
from .base import GuardedRobot


class FakeRobot(GuardedRobot):
    robot_source = RobotSource.FAKE

    def __init__(self, *, stage_delay_s: float = 0.05, fault_stage: Stage | None = None,
                 timeout_stage: Stage | None = None, disconnected: bool = False,
                 max_request_age_s: float = 1.0) -> None:
        super().__init__(max_request_age_s=max_request_age_s)
        if not math.isfinite(stage_delay_s) or stage_delay_s < 0:
            raise ValueError("stage_delay_s must be finite and nonnegative")
        if any(s is not None and not isinstance(s, Stage) for s in (fault_stage, timeout_stage)):
            raise ValueError("fault/timeout stage must be Stage")
        self.stage_delay_s = stage_delay_s
        self.fault_stage = fault_stage
        self.timeout_stage = timeout_stage
        self.disconnected = disconnected
        self.completed_stages: list[Stage] = []

    def query_feedback(self) -> RobotFeedback:
        error = "CLOSED" if self._closed else "MOCK_DISCONNECTED" if self.disconnected else self._fault
        return RobotFeedback(self.robot_source, time.monotonic(), None, None,
                             error is None, "LOGICAL MOCK; NO PHYSICAL POSE", error)

    def _validate_device(self, request: ActionRequest) -> str | None:
        if self.disconnected:
            return "MOCK_DISCONNECTED"
        if request.motion_allowed or request.robot_xyz_mm is not None:
            return "MOCK_ONLY_NO_PHYSICAL_COORDINATES"
        if request.gripper_target_deg is not None and not 0 <= request.gripper_target_deg <= 90:
            return "GRIPPER_OUT_OF_RANGE"
        if request.speed_setting is not None and request.speed_setting > 100:
            return "SPEED_OUT_OF_RANGE"
        if request.acceleration_setting is not None and request.acceleration_setting > 10:
            return "ACCELERATION_OUT_OF_RANGE"
        return None

    def _perform(self, request: ActionRequest, started: float) -> StageResult:
        delay = self.stage_delay_s
        if request.stage is self.timeout_stage:
            delay = request.timeout_s
        if self._stop.wait(min(delay, request.timeout_s)):
            return self._result(request, StageStatus.REJECTED, started, "STOP_REQUESTED")
        if delay >= request.timeout_s:
            return self._result(request, StageStatus.TIMED_OUT, started, "MOCK_TIMEOUT")
        if self.disconnected:
            return self._result(request, StageStatus.FAULT, started, "MOCK_DISCONNECTED")
        if request.stage is self.fault_stage:
            return self._result(request, StageStatus.FAULT, started, "MOCK_FAULT")
        self.completed_stages.append(request.stage)
        return self._result(request, StageStatus.DRY_RUN, started)
