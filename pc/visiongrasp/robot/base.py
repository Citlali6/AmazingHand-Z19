"""Shared guarded stage sequencing; no hardware imports or implicit recovery."""
from __future__ import annotations

import threading
import time
from typing import Protocol, runtime_checkable

from ..contracts import ActionRequest, MOTION_STAGES, RobotFeedback, RobotSource, Stage, StageResult, StageStatus


@runtime_checkable
class RobotAdapter(Protocol):
    robot_source: RobotSource

    def begin_run(self, session: str) -> None: ...
    def query_feedback(self) -> RobotFeedback: ...
    def validate_motion(self, request: ActionRequest) -> str | None: ...
    def send_stage(self, request: ActionRequest) -> StageResult: ...
    def cancel_future_stages(self) -> None: ...
    def close(self) -> None: ...


class GuardedRobot:
    """One stage in flight. Failed sends consume their sequence and latch fault.

    The cancellation event is independent of the execution lock so STOP can wake
    an in-flight fake wait. It is a future-command barrier, not a physical stop.
    """

    def __init__(self, *, max_request_age_s: float = 1.0) -> None:
        if not 0 < max_request_age_s < float("inf"):
            raise ValueError("max_request_age_s must be finite and positive")
        self.max_request_age_s = max_request_age_s
        self._execution = threading.RLock()
        self._stop = threading.Event()
        self._closed = False
        self._fault: str | None = None
        self._session: str | None = None
        self._sessions: set[str] = set()
        self._sequence = 0
        self._stage_index = 0
        self._running = False
        self.history: list[StageResult] = []

    def begin_run(self, session: str) -> None:
        if not isinstance(session, str) or not session.strip():
            raise ValueError("session required")
        with self._execution:
            if self._closed:
                raise RuntimeError("CLOSED")
            if self._running:
                raise RuntimeError("BUSY")
            if session in self._sessions:
                raise ValueError("SESSION_REPLAY")
            if self._fault:
                raise RuntimeError("FAULT_REQUIRES_RECONNECT")
            self._sessions.add(session)
            self._session = session
            self._sequence = self._stage_index = 0
            self._stop.clear()

    def validate_motion(self, request: ActionRequest) -> str | None:
        with self._execution:
            if not isinstance(request, ActionRequest):
                return "INVALID_REQUEST"
            if self._closed:
                return "CLOSED"
            if self._stop.is_set():
                return "STOP_REQUESTED"
            if self._fault:
                return self._fault
            if request.run_session != self._session:
                return "SESSION_NOT_STARTED"
            if request.sequence != self._sequence:
                return "SEQUENCE_REPLAY_OR_GAP"
            age = time.monotonic() - request.created_monotonic_s
            if age < 0 or age > self.max_request_age_s:
                return "STALE_REQUEST"
            if request.stage is Stage.QUERY:
                return None
            if self._stage_index >= len(MOTION_STAGES) or request.stage is not MOTION_STAGES[self._stage_index]:
                return "INVALID_STAGE_ORDER"
            if not request.operator_confirmed:
                return "NOT_CONFIRMED"
            if not request.calibration_id:
                return "UNCALIBRATED"
            return self._validate_device(request)

    def send_stage(self, request: ActionRequest) -> StageResult:
        if not isinstance(request, ActionRequest):
            raise TypeError("request must be ActionRequest")
        with self._execution:
            started = time.monotonic()
            reason = self.validate_motion(request)
            if reason:
                result = self._result(request, StageStatus.REJECTED, started, reason)
                self.history.append(result)
                return result
            # Reserve before any I/O. A retry of a failed or uncertain command
            # must never execute a second time.
            self._sequence += 1
            self._running = True
            try:
                if request.stage is Stage.QUERY:
                    feedback = self.query_feedback()
                    status = StageStatus.FEEDBACK_CONFIRMED if feedback.communication_ok else StageStatus.FAULT
                    result = self._result(request, status, started, feedback.error)
                else:
                    result = self._perform(request, started)
                if result.status in (StageStatus.DRY_RUN, StageStatus.FEEDBACK_CONFIRMED):
                    if request.stage is not Stage.QUERY:
                        self._stage_index += 1
                elif result.status in (StageStatus.FAULT, StageStatus.TIMED_OUT):
                    self._fault = result.error or result.status.value
                self.history.append(result)
                return result
            except Exception:
                # No raw exception messages: SDK/transport errors may contain
                # machine paths or device details unsuitable for public logs.
                self._fault = "ADAPTER_EXCEPTION"
                result = self._result(request, StageStatus.FAULT, started, self._fault)
                self.history.append(result)
                return result
            finally:
                self._running = False

    @staticmethod
    def _result(request: ActionRequest, status: StageStatus, started: float, error: str | None = None) -> StageResult:
        return StageResult(request.run_session, request.sequence, request.stage.value, status,
                           started, time.monotonic(), error)

    def cancel_future_stages(self) -> None:
        self._stop.set()

    def close(self) -> None:
        self.cancel_future_stages()
        with self._execution:
            self._closed = True

    def _validate_device(self, request: ActionRequest) -> str | None:
        raise NotImplementedError

    def _perform(self, request: ActionRequest, started: float) -> StageResult:
        raise NotImplementedError
