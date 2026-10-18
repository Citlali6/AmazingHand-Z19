"""Persistent native NCNN bridge; no Python NCNN package or system changes."""
from __future__ import annotations

import json
from pathlib import Path
import select
import subprocess
import tempfile

import cv2

from app.vision.detector import BaseDetector


class NcnnCppDetector(BaseDetector):
    name = 'ncnn_cpp_aarch64'

    def __init__(self, model_dir, executable, input_size=416, num_threads=3,
                 conf=.35, iou=.45, timeout=20):
        super().__init__(conf, iou)
        self.timeout = timeout
        self.inference_ms = None
        self.temp = tempfile.TemporaryDirectory(prefix='ah-vision-', dir='/run')
        self.image = Path(self.temp.name) / 'input.bmp'
        self.proc = subprocess.Popen([str(executable), str(model_dir), str(input_size),
                                      str(num_threads), str(conf), str(iou)],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     universal_newlines=True, bufsize=1)

    def detect_raw(self, frame_bgr):
        if self.proc.poll() is not None:
            raise RuntimeError('NCNN bridge exited: %s' % self.proc.returncode)
        if not cv2.imwrite(str(self.image), frame_bgr):
            raise RuntimeError('bridge image write failed')
        self.proc.stdin.write(json.dumps(str(self.image)) + '\n')
        self.proc.stdin.flush()
        if not select.select([self.proc.stdout], [], [], self.timeout)[0]:
            self.proc.kill()
            raise RuntimeError('NCNN bridge inference timeout')
        reply = json.loads(self.proc.stdout.readline())
        if reply.get('error'):
            raise RuntimeError(reply['error'])
        self.inference_ms = reply['inference_ms']
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
