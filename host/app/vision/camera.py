"""相机采集抽象 —— OpenCV UVC（板端）/ 图片序列（PC 无相机时演示与测试）。"""

from __future__ import annotations

from pathlib import Path
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
import json
import time
from urllib.request import ProxyHandler, build_opener

import cv2
import numpy as np


class CameraSource(ABC):
    @abstractmethod
    def read(self) -> np.ndarray | None:
        """返回一帧 BGR 图像；无帧返回 None。"""
    def close(self) -> None: ...


class CameraUnavailable(RuntimeError):
    """No new, fresh, valid image; callers must suppress detection/actions."""


class DuplicateFrame(CameraUnavailable):
    """A fresh JPEG was already consumed; wait, never infer on it again."""


@dataclass(frozen=True)
class CameraFrame:
    bgr: np.ndarray
    jpeg: bytes
    sequence: int
    session: str
    capture_monotonic: float
    received_monotonic: float
    source_age_ms: float
    timings_ms: dict = field(default_factory=dict)
    width: int = 0
    height: int = 0

    def age_ms(self):
        # Works across hosts too: never subtract a PC clock from the board clock.
        return self.source_age_ms + (time.monotonic() - self.received_monotonic) * 1000


class PreviewCamera(CameraSource):
    """Reuse the IMX214 service; require atomic JPEG identity headers.

    Existing preview packages without these headers fail explicitly. Deploy the
    additive HTTP server update; never guess a JPEG's identity from status.json.
    """

    def __init__(self, url='http://127.0.0.1:9000', max_age_ms=800, timeout=2,
                 decode_bgr=True):
        self.url = url.rstrip('/')
        self.max_age_ms = float(max_age_ms)
        self.timeout = timeout
        self.opener = build_opener(ProxyHandler({}))
        self.last = None
        self.decode_bgr = decode_bgr

    def read_packet(self):
        try:
            status_started = time.monotonic()
            with self.opener.open(self.url + '/status.json', timeout=self.timeout) as response:
                status = json.loads(response.read(65536))
            if status.get('state') != 'LIVE':
                raise CameraUnavailable('camera state: ' + str(status.get('state')))
            started = time.monotonic()
            timings = {'status_http': (started - status_started) * 1000}
            with self.opener.open(self.url + '/frame.jpg', timeout=self.timeout) as response:
                headers = response.headers
                data = response.read(8 * 1024 * 1024 + 1)
                seq = int(headers['X-Sequence'])
                stamp = float(headers['X-Capture-Monotonic'])
                age = float(headers['X-Frame-Age-Ms'])
                session = headers['X-Camera-Session']
            received = time.monotonic()
            timings['jpeg_http'] = (received - started) * 1000
            for header, key in [('X-Copy-Ms', 'camera_copy'), ('X-Encode-Ms', 'camera_encode')]:
                if headers.get(header) is not None:
                    timings[key] = float(headers[header])
            # Whole HTTP duration is a conservative upper bound on transit age.
            age += (received - started) * 1000
            if (not session or seq < 0 or not np.isfinite(stamp) or stamp < 0
                    or not np.isfinite(age) or age < 0 or age > self.max_age_ms):
                raise CameraUnavailable('invalid or stale frame metadata')
            identity = (session, seq)
            if self.last is not None and self.last[0] == session:
                if seq == self.last[1]:
                    raise DuplicateFrame('duplicate frame; waiting for a new sequence')
                if seq < self.last[1]:
                    raise CameraUnavailable('reordered frame')
            if (len(data) > 8 * 1024 * 1024 or not data.startswith(b'\xff\xd8')
                    or not data.endswith(b'\xff\xd9')):
                raise CameraUnavailable('invalid JPEG')
            decode_started = time.monotonic()
            frame = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR) if self.decode_bgr else None
            if self.decode_bgr and frame is None:
                raise CameraUnavailable('JPEG decode failed')
            timings['bgr_decode'] = (time.monotonic() - decode_started) * 1000
            width = int(headers.get('X-Frame-Width', frame.shape[1] if frame is not None else 0))
            height = int(headers.get('X-Frame-Height', frame.shape[0] if frame is not None else 0))
            if width <= 0 or height <= 0 or width > 8192 or height > 8192:
                raise CameraUnavailable('atomic JPEG geometry missing; update preview HTTP server')
            if frame is not None and (width, height) != (frame.shape[1], frame.shape[0]):
                raise CameraUnavailable('decoded JPEG geometry mismatch')
            self.last = identity
            packet = CameraFrame(frame, data, seq, session, stamp, received, age, timings, width, height)
            if packet.age_ms() > self.max_age_ms:
                raise CameraUnavailable('frame expired during decode')
            return packet
        except CameraUnavailable:
            raise
        except Exception as error:
            raise CameraUnavailable('camera HTTP/metadata failure: %s' % error) from error

    def read(self):
        packet = self.read_packet()
        if packet.bgr is not None:
            return packet.bgr
        frame = cv2.imdecode(np.frombuffer(packet.jpeg, np.uint8), cv2.IMREAD_COLOR)
        if frame is None:
            raise CameraUnavailable('JPEG decode failed')
        if (frame.shape[1], frame.shape[0]) != (packet.width, packet.height):
            raise CameraUnavailable('decoded JPEG geometry mismatch')
        if packet.age_ms() > self.max_age_ms:
            raise CameraUnavailable('frame expired during decode')
        return frame

    def close(self):
        pass


class OpenCVCamera:
    """板端 USB 相机（UVC → /dev/video0）。"""

    def __init__(self, index: int = 0, width: int = 1280, height: int = 720,
                 fps: int = 30):
        self._cap = cv2.VideoCapture(index)
        self._cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self._cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        self._cap.set(cv2.CAP_PROP_FPS, fps)
        if not self._cap.isOpened():
            raise RuntimeError(f"camera {index} open failed（检查接线/权限）")

    def read(self) -> np.ndarray | None:
        ok, frame = self._cap.read()
        return frame if ok else None

    def close(self) -> None:
        self._cap.release()


class ImageFolderSource:
    """PC 演示/测试：循环读取目录内图片，模拟视频流（无相机环境）。"""

    def __init__(self, folder: str | Path, loop: bool = True):
        exts = {".jpg", ".jpeg", ".png", ".bmp"}
        self._files = sorted(p for p in Path(folder).iterdir() if p.suffix.lower() in exts)
        if not self._files:
            raise FileNotFoundError(f"no images in {folder}")
        self._i = 0
        self._loop = loop

    def read(self) -> np.ndarray | None:
        if self._i >= len(self._files):
            if not self._loop:
                return None
            self._i = 0
        frame = cv2.imread(str(self._files[self._i]))
        self._i += 1
        return frame

    def close(self) -> None:
        pass


def build_camera(settings: dict) -> CameraSource:
    cs = settings.get("camera", {})
    if cs.get("type") == "preview_http":
        return PreviewCamera(cs.get('url', 'http://127.0.0.1:9000'),
                             cs.get('max_age_ms', 800), cs.get('timeout_s', 2))
    if cs.get("type") == "images":
        return ImageFolderSource(cs["folder"])
    return OpenCVCamera(index=int(cs.get("index", 0)),
                        width=int(cs.get("width", 1280)),
                        height=int(cs.get("height", 720)),
                        fps=int(cs.get("fps", 30)))
