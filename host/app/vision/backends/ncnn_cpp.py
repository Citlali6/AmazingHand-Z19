"""Persistent native NCNN bridge; no Python NCNN package or system changes."""
from __future__ import annotations

import json
from pathlib import Path
import select
import subprocess
import tempfile
import time

import cv2

from app.vision.detector import BaseDetector
from app.vision.camera import CameraUnavailable


class NcnnCppDetector(BaseDetector):
    name = 'ncnn_cpp_aarch64'

    def __init__(self, model_dir, executable, input_size=416, num_threads=3,
                 conf=.35, iou=.45, timeout=20):
        super().__init__(conf, iou)
        self.timeout = timeout
        self.inference_ms = None
        self.native_timings_ms = {}
        self.bridge_timings_ms = {}
        self.bridge_input_bytes = None
        self.temp = tempfile.TemporaryDirectory(prefix='ah-vision-', dir='/run')
        self.image = Path(self.temp.name) / 'input.bmp'
        self.proc = subprocess.Popen([str(executable), str(model_dir), str(input_size),
                                      str(num_threads), str(conf), str(iou)],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     universal_newlines=True, bufsize=1)

    def detect_raw(self, frame_bgr, deadline_monotonic=None):
        started = time.monotonic()
        self.image = Path(self.temp.name) / 'input.bmp'
        if not cv2.imwrite(str(self.image), frame_bgr):
            raise RuntimeError('bridge image write failed')
        metadata = ([frame_bgr.shape[1], frame_bgr.shape[0], deadline_monotonic]
                    if deadline_monotonic is not None else None)
        return self._run(started, metadata)

    def detect_jpeg(self, jpeg, width, height, deadline_monotonic):
        """Transmit the exact source JPEG, decode once in the native process."""
        started = time.monotonic()
        self.image = Path(self.temp.name) / 'input.jpg'
        self.image.write_bytes(jpeg)
        return self._run(started, [width, height, deadline_monotonic])

    def _run(self, started, geometry_deadline=None):
        if self.proc.poll() is not None:
            raise RuntimeError('NCNN bridge exited: %s' % self.proc.returncode)
        written = time.monotonic()
        request = ([str(self.image)] + geometry_deadline if geometry_deadline is not None
                   else str(self.image))
        self.proc.stdin.write(json.dumps(request) + '\n')
        self.proc.stdin.flush()
        if not select.select([self.proc.stdout], [], [], self.timeout)[0]:
            self.proc.kill()
            raise RuntimeError('NCNN bridge inference timeout')
        reply = json.loads(self.proc.stdout.readline())
        if reply.get('error'):
            if reply.get('error_code') == 'STALE_INPUT':
                raise CameraUnavailable('source expired before native forward')
            raise RuntimeError(reply['error'])
        self.inference_ms = reply['inference_ms']
        self.native_timings_ms = reply.get('timings_ms', {})
        self.bridge_timings_ms = dict(write=(written-started)*1000,
                                      roundtrip=(time.monotonic()-written)*1000)
        self.bridge_input_bytes = self.image.stat().st_size
        return [(row[0], row[1], tuple(row[2:6])) for row in reply['detections']]

    def close(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        for pipe in (self.proc.stdin, self.proc.stdout):
            pipe.close()
        self.temp.cleanup()
