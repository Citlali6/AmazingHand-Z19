"""Threaded, explicitly confirmed FakeRobot task controller; no serial SDK imports."""
from __future__ import annotations

from dataclasses import asdict
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import threading
import time
from typing import Callable, Any
import uuid

from visiongrasp.contracts import (
    ActionRequest, FramePacket, MOTION_STAGES, RobotSource, StageStatus,
    TaskStatus, VisionTarget,
)


class TaskLog:
    def __init__(self, directory: Path, session: str):
        directory.mkdir(parents=True, exist_ok=True)
        self.path = directory / f"{session}.jsonl"
        self._lock = threading.Lock()

    def write(self, event: str, **fields: Any) -> None:
        row = {"utc": datetime.now(timezone.utc).isoformat(), "event": event,
               "mode": "MOCK", "robot_source": "FAKE", "robot_xyz_mm": None, **fields}
        with self._lock, self.path.open("a", encoding="utf-8", newline="\n") as stream:
            stream.write(json.dumps(row, ensure_ascii=False, allow_nan=False) + "\n")


class DemoController:
    """Only a FAKE source may execute here; real integration belongs to Issue #10."""

    def __init__(self, robot: Any, log_dir: Path, *, clock: Callable[[], float] = time.monotonic,
                 max_frame_age_s: float = 0.5, target_tolerance_px: float = 15.0,
                 stage_timeout_s: float = 2.0):
        if getattr(robot, "robot_source", None) != RobotSource.FAKE:
            raise ValueError("DemoController only accepts an explicitly FAKE robot")
        for value in (max_frame_age_s, target_tolerance_px, stage_timeout_s):
            if not math.isfinite(value) or value <= 0:
                raise ValueError("timeouts and tolerance must be positive finite values")
        self.robot = robot
        self.clock = clock
        self.max_frame_age_s = max_frame_age_s
        self.target_tolerance_px = target_tolerance_px
        self.stage_timeout_s = stage_timeout_s
        self.session = str(uuid.uuid4())
        self.log = TaskLog(Path(log_dir), self.session)
        self.status = TaskStatus.IDLE
        self.error: str | None = None
        self.current_stage: str | None = None
        self.results = []
        self.completed_stages = 0
        self.feedback = None
        self.frame: FramePacket | None = None
        self.targets: list[VisionTarget] = []
        self.selected: VisionTarget | None = None
        self._lock = threading.RLock()
        self._cancel = threading.Event()
        self._worker: threading.Thread | None = None
        self._closed = False
        self.log.write("DEMO_OPEN", monotonic_s=self.clock())

    def _target_fields(self, target: VisionTarget | None = None) -> dict:
        target = target or self.selected
        if target is None:
            return {"camera_source": None, "frame_id": None, "calibration_id": None}
        return {"camera_source": target.source.value, "camera_session": target.camera_session,
                "frame_id": target.frame_id, "capture_monotonic_s": target.capture_monotonic_s,
                "calibration_id": target.calibration_id, "object_label": target.object_label,
                "center_uv_px": target.center_uv_px, "table_xy_mm": target.table_xy_mm}

    def observe(self, frame: FramePacket | None, targets: list[VisionTarget]) -> None:
        with self._lock:
            previous = self.selected
            self.frame = frame
            # Never accept targets detached from the actual observed frame.
            self.targets = [] if frame is None else [t for t in targets if
                t.camera_session == frame.camera_session and t.frame_id == frame.frame_id
                and t.capture_monotonic_s == frame.capture_monotonic_s
                and t.source == frame.source and t.frame_wh_px == frame.frame_wh_px]
            if previous is not None:
                matches = [t for t in self.targets if t.object_label == previous.object_label
                           and t.camera_session == previous.camera_session and t.source == previous.source
                           and t.calibration_id == previous.calibration_id
                           and math.dist(t.center_uv_px, previous.center_uv_px) <= self.target_tolerance_px]
                self.selected = min(matches, key=lambda t: math.dist(t.center_uv_px, previous.center_uv_px)) if matches else None
            if self.status == TaskStatus.RUNNING:
                reason = self._guard()
                if reason:
                    self.stop(reason)

    def select(self, index: int) -> bool:
        with self._lock:
            if self._closed or self.status == TaskStatus.RUNNING or not 0 <= index < len(self.targets):
                return False
            self.selected = self.targets[index]
            self.error = None
            self.log.write("TARGET_SELECTED", **self._target_fields(), monotonic_s=self.clock())
            return True

    def invalidate_selection(self, reason: str = "CALIBRATION_STARTED") -> None:
        self.stop(reason)
        with self._lock:
            self.selected = None
            self.targets = []

    def _guard(self) -> str | None:
        if self._closed:
            return "CLOSED"
        if self.frame is None:
            return "NO_FRAME"
        age = self.clock() - self.frame.capture_monotonic_s
        if age < 0 or age > self.max_frame_age_s:
            return "STALE_FRAME"
        target = self.selected
        if target is None:
            return "NO_SELECTED_TARGET"
        if not target.valid:
            return target.rejected_reason or "INVALID_TARGET"
        if target.table_xy_mm is None or not target.calibration_id:
            return "UNCALIBRATED"
        if target.frame_id != self.frame.frame_id or target.camera_session != self.frame.camera_session:
            return "TARGET_FRAME_MISMATCH"
        return None

    def start(self, *, operator_confirmed: bool) -> bool:
        with self._lock:
            reason = self._guard()
            if self.status == TaskStatus.RUNNING or (self._worker is not None and self._worker.is_alive()):
                reason = "ALREADY_RUNNING"
            elif not operator_confirmed:
                reason = "OPERATOR_NOT_CONFIRMED"
            if reason:
                self.error = reason
                self.log.write("REQUEST_REJECTED", error=reason, **self._target_fields(), monotonic_s=self.clock())
                return False
            self._cancel.clear()
            self.error = None
            self.results = []
            self.completed_stages = 0
            self.current_stage = None
            self.status = TaskStatus.RUNNING
            run_session = str(uuid.uuid4())
            try:
                self.robot.begin_run(run_session)
            except Exception as exc:
                self.status = TaskStatus.FAULT
                self.error = f"ROBOT_BEGIN_FAILED: {type(exc).__name__}"
                self.log.write("TASK_FAULT", error=self.error)
                return False
            frozen = self.selected
            self.log.write("MOCK_RUN_STARTED", run_session=run_session, **self._target_fields(), monotonic_s=self.clock())
            self._worker = threading.Thread(target=self._execute, args=(run_session, frozen), daemon=True,
                                            name="visiongrasp-fake-task")
            self._worker.start()
            return True

    def _execute(self, run_session: str, frozen: VisionTarget) -> None:
        try:
            for sequence, stage in enumerate(MOTION_STAGES):
                with self._lock:
                    reason = self._guard()
                    if self.selected and math.dist(self.selected.center_uv_px, frozen.center_uv_px) > self.target_tolerance_px:
                        reason = "TARGET_MOVED"
                    if self._cancel.is_set() or reason:
                        self.stop(reason or "STOP_REQUESTED")
                        return
                    self.current_stage = stage.value
                    request = ActionRequest(run_session, sequence, stage,
                                            operator_confirmed=True, calibration_id=frozen.calibration_id,
                                            motion_allowed=False, created_monotonic_s=self.clock(),
                                            timeout_s=self.stage_timeout_s)
                    self.log.write("STAGE_REQUEST", run_session=run_session, sequence=sequence,
                                   stage=stage.value, **self._target_fields(), monotonic_s=self.clock())
                # Blocking adapter execution stays outside the GUI thread and controller lock.
                result = self.robot.send_stage(request)
                with self._lock:
                    self.results.append(result)
                    self.log.write("STAGE_RESULT", **asdict(result), **self._target_fields(), monotonic_s=self.clock())
                    if self._cancel.is_set():
                        return
                    if result.status != StageStatus.DRY_RUN:
                        self.status = TaskStatus.FAULT
                        self.error = result.error or result.status.value
                        self.robot.cancel_future_stages()
                        self.log.write("TASK_FAULT", error=self.error, run_session=run_session)
                        return
                feedback = self.robot.query_feedback()
                with self._lock:
                    if self._cancel.is_set():
                        return
                    if feedback.robot_source != RobotSource.FAKE or not feedback.communication_ok:
                        raise RuntimeError("INVALID_FAKE_FEEDBACK")
                    self.feedback = feedback
                    self.completed_stages += 1
            with self._lock:
                if not self._cancel.is_set():
                    self.status = TaskStatus.IDLE
                    self.log.write("MOCK_SEQUENCE_COMPLETED", run_session=run_session,
                                   completed_stages=self.completed_stages, **self._target_fields())
        except Exception as exc:
            with self._lock:
                self.status = TaskStatus.FAULT
                self.error = f"{type(exc).__name__}: {exc}"
                self._cancel.set()
                self.robot.cancel_future_stages()
                self.log.write("TASK_FAULT", error=self.error, run_session=run_session)

    def stop(self, reason: str = "OPERATOR_STOP") -> None:
        with self._lock:
            if self._cancel.is_set():
                return
            self._cancel.set()
            self.robot.cancel_future_stages()
            self.status = TaskStatus.STOP_REQUESTED
            self.error = reason
            self.log.write("STOP_REQUESTED", error=reason, **self._target_fields(), monotonic_s=self.clock())

    def snapshot(self) -> dict:
        with self._lock:
            return {"status": self.status.value, "error": self.error,
                    "stage": self.current_stage, "completed_stages": self.completed_stages,
                    "selected": self.selected, "feedback": self.feedback,
                    "robot_source": "FAKE", "robot_xyz_mm": None}

    def wait(self, timeout: float = 2.0) -> bool:
        worker = self._worker
        if worker is not None:
            worker.join(timeout)
        return worker is None or not worker.is_alive()

    def close(self) -> None:
        self.stop("APPLICATION_CLOSED")
        with self._lock:
            self._closed = True
        if not self.wait(2.0):
            raise RuntimeError("Fake adapter did not stop within close timeout")
        self.robot.close()
        self.log.write("DEMO_CLOSED")
