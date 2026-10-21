"""Fail-closed, lazy RoArm M2-S adapter for later supervised bench tests.

The pinned SDK pose_ctrl has no speed/acceleration controls. Cartesian motion
therefore remains disabled; no requested limit is silently ignored. Query and
measured low-speed gripper control are implemented with single-shot transport.
"""
from __future__ import annotations

from dataclasses import dataclass
import math
import threading
import time
from typing import Any, Callable

from ..contracts import ActionRequest, RobotFeedback, RobotSource, Stage, StageResult, StageStatus
from .base import GuardedRobot


@dataclass(frozen=True)
class BenchSafety:
    """No default measured workspace, speed, gripper direction or limits."""
    calibration_id: str
    xyz_bounds_mm: tuple[tuple[float, float], tuple[float, float], tuple[float, float]]
    gripper_bounds_deg: tuple[float, float]
    max_speed: int
    max_acceleration: int
    base_fixed: bool = False
    workspace_clear: bool = False
    power_disconnect_accessible: bool = False
    measured_on_site: bool = False

    def __post_init__(self) -> None:
        if not self.calibration_id or len(self.xyz_bounds_mm) != 3:
            raise ValueError("measured calibration and XYZ bounds required")
        for bounds in (*self.xyz_bounds_mm, self.gripper_bounds_deg):
            if len(bounds) != 2 or any(isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) for v in bounds) or bounds[0] >= bounds[1]:
                raise ValueError("finite increasing bounds required")
        if not 0 <= self.gripper_bounds_deg[0] < self.gripper_bounds_deg[1] <= 90:
            raise ValueError("gripper bounds outside SDK range")
        if type(self.max_speed) is not int or not 1 <= self.max_speed <= 100:
            raise ValueError("first-bench speed must be in [1,100]")
        if type(self.max_acceleration) is not int or not 1 <= self.max_acceleration <= 10:
            raise ValueError("first-bench acceleration must be in [1,10]")
        for name in ("base_fixed", "workspace_clear", "power_disconnect_accessible", "measured_on_site"):
            if type(getattr(self, name)) is not bool:
                raise ValueError("safety confirmations must be bool")


def _sdk_factory(**kwargs: Any) -> Any:
    """Import/construct only after connect's explicit physical gate.

    Override the retry layer, not _request_once: exceptions and short writes
    propagate, and every generated command causes at most one serial write.
    """
    from roarm_sdk.roarm import roarm
    from roarm_sdk.common import JsonCmd

    class SingleShotRoArm(roarm):
        def _write(self, command: bytes, method: Any = None) -> None:
            if method is not None or self.host:
                raise RuntimeError("SERIAL_ONLY")
            self._serial_port.reset_input_buffer()
            if self.base_controller is not None:
                self.base_controller.rl.buf.clear()
            written = self._serial_port.write(command)
            if type(written) is not int or written != len(command):
                raise IOError("SHORT_WRITE")
            # Do not call flush(): some drivers can block beyond write_timeout.

        def _res(self, real_command: bytes, genre: int) -> Any:
            self._write(real_command)
            if genre != JsonCmd.FEEDBACK_GET:
                return real_command
            data = self._read(genre)
            if not isinstance(data, dict) or data.get("T") != 1051:
                return None
            processed = self._process_received(data, genre)
            return processed[0] if isinstance(processed, list) and len(processed) == 1 else None

    return SingleShotRoArm(**kwargs)


class RoArmSerialRobot(GuardedRobot):
    robot_source = RobotSource.ROARM_SERIAL
    _ports: set[str] = set()
    _ports_lock = threading.Lock()

    def __init__(self, *, mode: str = "mock", port: str | None = None,
                 onsite_confirmed: bool = False, safety: BenchSafety | None = None,
                 sdk_factory: Callable[..., Any] | None = None, io_timeout_s: float = 0.1,
                 max_request_age_s: float = 1.0) -> None:
        super().__init__(max_request_age_s=max_request_age_s)
        if not math.isfinite(io_timeout_s) or not 0 < io_timeout_s <= 0.5:
            raise ValueError("io_timeout_s must be in (0,0.5]")
        self.mode = mode
        self.port = port
        self.onsite_confirmed = onsite_confirmed
        self.safety = safety
        self.io_timeout_s = io_timeout_s
        self._factory = sdk_factory or _sdk_factory
        self._sdk: Any = None
        self._owns_port = False
        self._last_feedback: RobotFeedback | None = None

    def connect(self) -> None:
        with self._execution:
            if self._closed or self._fault:
                raise RuntimeError("RECREATE_ADAPTER_AFTER_FAULT_OR_CLOSE")
            if self._sdk is not None:
                return
            if self.mode != "real" or not self.port or self.onsite_confirmed is not True:
                raise PermissionError("REAL_MODE_PORT_AND_CURRENT_ONSITE_CONFIRMATION_REQUIRED")
            key = self.port.casefold()
            with self._ports_lock:
                if key in self._ports:
                    raise RuntimeError("PORT_ALREADY_OWNED")
                self._ports.add(key)
                self._owns_port = True
            try:
                self._sdk = self._factory(roarm_type="roarm_m2", port=self.port,
                                          baudrate=115200, timeout=self.io_timeout_s,
                                          debug=False, gripper_type="angular_direct")
                self._sdk._serial_port.write_timeout = self.io_timeout_s
            except Exception:
                if self._sdk is not None:
                    self._sdk._serial_port.close()
                self._sdk = None
                self._release_port()
                self._fault = "CONNECT_FAILED"
                raise RuntimeError(self._fault) from None

    def _release_port(self) -> None:
        if self._owns_port:
            with self._ports_lock:
                self._ports.discard(self.port.casefold())
            self._owns_port = False

    def query_feedback(self) -> RobotFeedback:
        with self._execution:
            error = "CLOSED" if self._closed else self._fault or ("DISCONNECTED" if self._sdk is None else None)
            angles = xyz = None
            if error is None:
                try:
                    data = self._sdk.feedback_get()
                    if not isinstance(data, (list, tuple)) or len(data) != 7 or any(isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) for v in data):
                        raise ValueError("INVALID_FEEDBACK")
                    xyz = tuple(float(v) for v in data[:3])
                    # Fixed SDK already undoes angular_direct gripper inversion.
                    angles = tuple(math.degrees(v) for v in data[3:])
                    limits = ((-180, 180), (-90, 90), (0, 180), (0, 90))
                    if any(not low - 0.5 <= a <= high + 0.5 for a, (low, high) in zip(angles, limits)):
                        raise ValueError("INVALID_FEEDBACK")
                except Exception:
                    error = self._fault = "INVALID_OR_MISSING_FEEDBACK"
                    xyz = angles = None
            result = RobotFeedback(self.robot_source, time.monotonic(), angles, xyz,
                                   error is None, "M2: xyz_mm + 4 joint_deg" if error is None else None, error)
            self._last_feedback = result
            return result

    def _validate_device(self, request: ActionRequest) -> str | None:
        if self._sdk is None:
            return "DISCONNECTED"
        if self.mode != "real" or self.onsite_confirmed is not True or not request.motion_allowed:
            return "MOTION_NOT_AUTHORIZED"
        s = self.safety
        if s is None or not all((s.measured_on_site, s.base_fixed, s.workspace_clear, s.power_disconnect_accessible)):
            return "MEASURED_WORKSPACE_REQUIRED"
        if request.calibration_id != s.calibration_id:
            return "CALIBRATION_MISMATCH"
        if request.robot_xyz_mm is None:
            return "ROBOT_COORDINATES_REQUIRED"
        if any(not low <= v <= high for v, (low, high) in zip(request.robot_xyz_mm, s.xyz_bounds_mm)):
            return "OUT_OF_WORKSPACE"
        if request.speed_setting is not None and request.speed_setting != int(request.speed_setting):
            return "INTEGER_SPEED_REQUIRED"
        if request.speed_setting is None or not 1 <= request.speed_setting <= s.max_speed:
            return "SPEED_OUT_OF_RANGE"
        if request.acceleration_setting is None or request.acceleration_setting != int(request.acceleration_setting) or not 1 <= request.acceleration_setting <= s.max_acceleration:
            return "ACCELERATION_OUT_OF_RANGE"
        if request.gripper_target_deg is None or not s.gripper_bounds_deg[0] <= request.gripper_target_deg <= s.gripper_bounds_deg[1]:
            return "GRIPPER_OUT_OF_RANGE"
        f = self._last_feedback
        if f is None or not f.communication_ok or time.monotonic() - f.received_monotonic_s > self.max_request_age_s:
            return "FRESH_ROBOT_FEEDBACK_REQUIRED"
        if request.stage not in (Stage.GRIP, Stage.RELEASE):
            return "CARTESIAN_SPEED_UNVERIFIED"
        # Gripper-only control must not silently ignore a requested XYZ change.
        if math.dist(request.robot_xyz_mm, f.end_xyz_mm) > 2:
            return "GRIPPER_STAGE_REQUIRES_CURRENT_POSE"
        return None

    def _perform(self, request: ActionRequest, started: float) -> StageResult:
        if self._stop.is_set():
            return self._result(request, StageStatus.REJECTED, started, "STOP_REQUESTED")
        self._sdk._serial_port.write_timeout = min(self.io_timeout_s, request.timeout_s)
        # gripper_angle_ctrl hides the transport result by unconditionally
        # returning 1; use the verified lower-level joint method instead.
        result = self._sdk.joint_angle_ctrl(joint=4, angle=request.gripper_target_deg,
                                            speed=int(request.speed_setting), acc=int(request.acceleration_setting))
        if not isinstance(result, bytes) or not result:
            return self._result(request, StageStatus.FAULT, started, "SEND_FAILED")
        self.history.append(StageResult(request.run_session, request.sequence, request.stage.value,
                                        StageStatus.SENT, started, None))
        deadline = started + request.timeout_s
        stable = 0
        while time.monotonic() < deadline:
            if self._stop.is_set():
                self._fault = "STOP_REQUESTED_AFTER_SEND"
                return self._result(request, StageStatus.REJECTED, started, "STOP_REQUESTED_AFTER_SEND")
            feedback = self.query_feedback()
            if not feedback.communication_ok:
                return self._result(request, StageStatus.FAULT, started, feedback.error)
            if time.monotonic() >= deadline:
                break
            stable = stable + 1 if abs(feedback.joint_angles_deg[3] - request.gripper_target_deg) <= 1 else 0
            if stable >= 2:
                return self._result(request, StageStatus.FEEDBACK_CONFIRMED, started)
            self._stop.wait(min(0.02, max(0, deadline - time.monotonic())))
        return self._result(request, StageStatus.TIMED_OUT, started, "FEEDBACK_NOT_AT_TARGET")

    def close(self) -> None:
        self.cancel_future_stages()
        with self._execution:
            try:
                if self._sdk is not None:
                    self._sdk._serial_port.close()
            finally:
                self._sdk = None
                self._release_port()
                self._closed = True
