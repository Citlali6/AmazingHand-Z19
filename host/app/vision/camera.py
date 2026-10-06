"""相机采集抽象 —— OpenCV UVC（板端）/ 图片序列（PC 无相机时演示与测试）。"""

from __future__ import annotations

from pathlib import Path
from typing import Protocol

import cv2
import numpy as np


class CameraSource(Protocol):
    def read(self) -> np.ndarray | None:
        """返回一帧 BGR 图像；无帧返回 None。"""
    def close(self) -> None: ...


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
    if cs.get("type") == "images":
        return ImageFolderSource(cs["folder"])
    return OpenCVCamera(index=int(cs.get("index", 0)),
                        width=int(cs.get("width", 1280)),
                        height=int(cs.get("height", 720)),
                        fps=int(cs.get("fps", 30)))
