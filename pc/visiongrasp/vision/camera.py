"""Latest-only capture with explicit freshness and diagnostic state."""
from __future__ import annotations

import math
import threading
import time
import uuid
import zlib
from collections.abc import Callable

import cv2
import numpy as np

from visiongrasp.contracts import FramePacket, VisionSource


class CameraProvider:
    """One capture owner. Opening/reading happens on a worker, never the UI thread.

    Exact byte repeats are conservative freeze suspects, not proof of driver age.
    They never refresh the accepted packet's timestamp. Recreate the provider
    after disconnect/close; there is deliberately no surprise device reopen.
    """

    def __init__(self, index=0, backend="dshow", width=1280, height=720,
                 max_age_s=0.5, read_timeout_s=1.0, capture_factory=None,
                 clock: Callable[[], float] = time.monotonic,
                 repeat_limit=3, black_mean_limit=1.0):
        backends = {"dshow": cv2.CAP_DSHOW, "msmf": cv2.CAP_MSMF, "any": cv2.CAP_ANY}
        if backend not in backends:
            raise ValueError("backend must be dshow, msmf or any")
        if type(index) is not int or index < 0:
            raise ValueError("index must be a nonnegative integer")
        if any(type(v) is not int or v <= 0 for v in (width, height, repeat_limit)):
            raise ValueError("dimensions and repeat_limit must be positive integers")
        if any(not math.isfinite(v) or v <= 0 for v in (max_age_s, read_timeout_s)):
            raise ValueError("freshness and timeout must be positive")
        if not 0 <= black_mean_limit <= 255:
            raise ValueError("black_mean_limit outside uint8 range")
        self._index, self._backend = index, backends[backend]
        self._width, self._height = width, height
        self._max_age_s, self._timeout_s = max_age_s, read_timeout_s
        self._factory = capture_factory or cv2.VideoCapture
        self._clock, self._repeat_limit, self._black_limit = clock, repeat_limit, black_mean_limit
        self._session = uuid.uuid4().hex
        self._lock, self._stop = threading.Lock(), threading.Event()
        self._capture, self._packet = None, None
        self._started = clock()
        self._last_response = self._started
        self._health = {"status": "OPENING", "camera_session": self._session,
                        "index": index, "requested_backend": backend, "actual_backend": None,
                        "requested_wh_px": (width, height), "actual_wh_px": None,
                        "reported_fps": None, "measured_fps": 0.0,
                        "first_frame_s": None, "accepted_frames": 0,
                        "read_failures": 0, "repeated_frames": 0, "error": None}
        self._thread = threading.Thread(target=self._run, name="vision-capture", daemon=True)
        self._thread.start()

    def _update(self, **values):
        with self._lock:
            self._health.update(values)

    def _run(self):
        capture = None
        try:
            capture = self._factory(self._index, self._backend)
            with self._lock:
                self._capture = capture
            if self._stop.is_set():
                return
            if not capture.isOpened():
                self._update(status="OPEN_FAILED", error="camera unavailable or in use")
                return
            capture.set(cv2.CAP_PROP_FRAME_WIDTH, self._width)
            capture.set(cv2.CAP_PROP_FRAME_HEIGHT, self._height)
            # Backend support is not guaranteed; worker timeout health is independent.
            capture.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, self._timeout_s * 1000)
            reported_fps = float(capture.get(cv2.CAP_PROP_FPS))
            backend = capture.getBackendName() if hasattr(capture, "getBackendName") else "unknown"
            self._update(actual_backend=backend,
                         reported_fps=reported_fps if math.isfinite(reported_fps) and reported_fps > 0 else None,
                         status="NO_FRAME")
            previous_digest, repeats, accepted = None, 0, 0
            first_time = None
            while not self._stop.is_set():
                ok, frame = capture.read()
                now = self._clock()
                with self._lock:
                    self._last_response = now
                if self._stop.is_set():
                    break
                if not ok or frame is None:
                    with self._lock:
                        self._health["read_failures"] += 1
                        self._health.update(status="READ_FAILED", error="camera read failed; frame withheld")
                    self._stop.wait(0.02)
                    continue
                if not isinstance(frame, np.ndarray) or frame.dtype != np.uint8 or frame.ndim != 3 or frame.shape[2] != 3:
                    self._update(status="INVALID_FRAME", error="expected uint8 BGR image")
                    continue
                height, width = frame.shape[:2]
                if not width or not height:
                    self._update(status="INVALID_FRAME", error="empty frame")
                    continue
                self._update(actual_wh_px=(width, height))
                if float(np.mean(frame)) <= self._black_limit:
                    self._update(status="BLACK_FRAME", error="black/underexposed image; frame withheld")
                    continue
                digest = zlib.crc32(frame.tobytes())
                if digest == previous_digest:
                    repeats += 1
                    with self._lock:
                        self._health["repeated_frames"] += 1
                    if repeats >= self._repeat_limit:
                        self._update(status="REPEATED_FRAME", error="exact repeated image; freeze suspected")
                    self._stop.wait(0.005)
                    continue
                previous_digest, repeats = digest, 0
                packet = FramePacket(frame.copy(), self._session, accepted, now,
                                     VisionSource.LIVE_PC_UVC, (width, height))
                accepted += 1
                if first_time is None:
                    first_time = now
                with self._lock:
                    self._packet = packet
                    self._health.update(status="CAMERA_OK", error=None, accepted_frames=accepted,
                                        first_frame_s=first_time - self._started,
                                        measured_fps=(accepted - 1) / (now - first_time) if now > first_time else 0.0)
        except Exception as exc:
            self._update(status="CAPTURE_ERROR", error=f"{type(exc).__name__}: capture failed")
        finally:
            if capture is not None:
                capture.release()
            if self._stop.is_set():
                self._update(status="CLOSED")

    @property
    def health(self):
        with self._lock:
            result = self._health.copy()
            last_response, packet = self._last_response, self._packet
        now = self._clock()
        if result["status"] not in {"CLOSED", "OPEN_FAILED", "CAPTURE_ERROR"}:
            if now - last_response > self._timeout_s:
                result.update(status="TIMEOUT", error="no capture response within read_timeout_s")
            elif result["status"] == "CAMERA_OK" and packet and now - packet.capture_monotonic_s > self._max_age_s:
                result.update(status="STALE", error="last accepted image is too old")
        return result

    def read_latest(self):
        if self.health["status"] != "CAMERA_OK":
            return None
        with self._lock:
            packet = self._packet
            if (self._health["status"] != "CAMERA_OK" or packet is None
                    or not 0 <= self._clock() - packet.capture_monotonic_s <= self._max_age_s):
                return None
            return FramePacket(packet.image.copy(), packet.camera_session, packet.frame_id,
                               packet.capture_monotonic_s, packet.source, packet.frame_wh_px)

    def close(self):
        self._stop.set()
        with self._lock:
            capture = self._capture
            self._packet = None
        # Driver read() can block; release tries to unblock it and join is bounded.
        if capture is not None:
            capture.release()
        self._thread.join(timeout=min(self._timeout_s, 1.0))
        self._update(status="CLOSED", error=None)


class SyntheticCamera:
    """Deterministic synthetic BGR tabletop; never presented as physical footage."""

    def __init__(self, width=640, height=480, clock=time.monotonic):
        if type(width) is not int or type(height) is not int or min(width, height) < 120:
            raise ValueError("synthetic dimensions must be integers >=120")
        self.width, self.height, self._clock = width, height, clock
        self._session, self._sequence, self._closed = uuid.uuid4().hex, 0, False

    @property
    def health(self):
        return {"status": "CLOSED" if self._closed else "CAMERA_OK",
                "actual_wh_px": (self.width, self.height), "source": "SYNTHETIC"}

    def read_latest(self):
        if self._closed:
            return None
        image = np.full((self.height, self.width, 3), 45, np.uint8)
        side = max(20, min(self.width, self.height) // 8)
        for x, y, color in ((self.width // 4, self.height // 3, (0, 0, 255)),
                            (self.width * 2 // 3, self.height * 3 // 5, (255, 0, 0))):
            cv2.rectangle(image, (x, y), (x + side - 1, y + side - 1), color, -1)
        packet = FramePacket(image, self._session, self._sequence, self._clock(),
                             VisionSource.SYNTHETIC, (self.width, self.height))
        self._sequence += 1
        return packet

    def close(self):
        self._closed = True
