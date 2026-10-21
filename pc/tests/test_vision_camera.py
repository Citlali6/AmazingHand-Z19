import queue
import threading
import time

import numpy as np
import pytest

from visiongrasp.contracts import VisionSource
from visiongrasp.vision import CameraProvider, SyntheticCamera


class Capture:
    """Injected capture owns no physical resource; queue controls capture order."""
    def __init__(self, opened=True):
        self.frames = queue.Queue()
        self.opened = opened
        self.released = threading.Event()
        self.settings = {}

    def isOpened(self):
        return self.opened

    def set(self, key, value):
        self.settings[key] = value
        return True

    def get(self, key):
        return 29.97

    def getBackendName(self):
        return "DUMMY_ONLY"

    def read(self):
        while not self.released.is_set():
            try:
                value = self.frames.get(timeout=.01)
                return value is not None, value
            except queue.Empty:
                pass
        return False, None

    def release(self):
        self.released.set()


def wait_for(predicate):
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.002)
    raise AssertionError("capture worker did not reach expected state")


def provider(capture, **kwargs):
    return CameraProvider(capture_factory=lambda index, backend: capture, **kwargs)


def frame(value=70):
    return np.full((120, 160, 3), value, np.uint8)


def test_synthetic_deterministic_source_sequences_and_close():
    first, second = SyntheticCamera(clock=lambda: 10.), SyntheticCamera(clock=lambda: 10.)
    a, b = first.read_latest(), second.read_latest()
    assert np.array_equal(a.image, b.image)
    assert a.source == VisionSource.SYNTHETIC and a.frame_id == 0
    assert first.read_latest().frame_id == 1
    first.close()
    assert first.read_latest() is None


def test_unavailable_device_no_frame_and_release():
    capture = Capture(opened=False)
    camera = provider(capture)
    try:
        wait_for(lambda: camera.health["status"] == "OPEN_FAILED")
        assert camera.read_latest() is None
        assert capture.released.is_set()
    finally:
        camera.close()


def test_actual_size_and_latest_only_no_shared_image_mutation():
    capture = Capture()
    camera = provider(capture, width=1280, height=720)
    try:
        for count, value in enumerate((40, 60, 80), start=1):
            capture.frames.put(frame(value))
            wait_for(lambda: camera.health["accepted_frames"] == count)
            # Windows monotonic may use a coarse system timer; sample over time.
            time.sleep(.02)
        wait_for(lambda: camera.health["accepted_frames"] == 3)
        packet = camera.read_latest()
        assert packet.frame_id == 2 and packet.frame_wh_px == (160, 120)
        assert packet.source == VisionSource.LIVE_PC_UVC
        assert camera.health["actual_wh_px"] == (160, 120)
        assert camera.health["reported_fps"] == 29.97
        assert camera.health["first_frame_s"] is not None
        assert camera.health["measured_fps"] > 0
        packet.image[:] = 0
        assert camera.read_latest().image.mean() == 80
    finally:
        camera.close()
    assert capture.released.is_set()
    assert camera.read_latest() is None


@pytest.mark.parametrize("bad,status", [(None, "READ_FAILED"),
                                       (np.zeros((120, 160, 3), np.uint8), "BLACK_FRAME"),
                                       (np.ones((120, 160), np.uint8), "INVALID_FRAME")])
def test_bad_stream_never_reissues_previous_valid_frame(bad, status):
    capture = Capture()
    camera = provider(capture)
    try:
        capture.frames.put(frame())
        wait_for(lambda: camera.health["accepted_frames"] == 1)
        capture.frames.put(bad)
        wait_for(lambda: camera.health["status"] == status)
        assert camera.read_latest() is None
        capture.frames.put(frame(90))
        wait_for(lambda: camera.health["accepted_frames"] == 2)
        assert camera.read_latest().frame_id == 1
    finally:
        camera.close()


def test_exact_repeat_does_not_refresh_timestamp_and_recovers_on_new_frame():
    capture = Capture()
    camera = provider(capture)
    try:
        capture.frames.put(frame())
        wait_for(lambda: camera.health["accepted_frames"] == 1)
        stamp = camera.read_latest().capture_monotonic_s
        for _ in range(3):
            capture.frames.put(frame())
        wait_for(lambda: camera.health["status"] == "REPEATED_FRAME")
        assert camera.health["accepted_frames"] == 1
        assert camera.read_latest() is None
        capture.frames.put(frame(90))
        wait_for(lambda: camera.health["accepted_frames"] == 2)
        assert camera.read_latest().capture_monotonic_s >= stamp
    finally:
        camera.close()


def test_timeout_and_stale_are_nonblocking():
    capture = Capture()
    now = [10.]
    camera = provider(capture, clock=lambda: now[0], max_age_s=.25, read_timeout_s=1.)
    try:
        capture.frames.put(frame())
        wait_for(lambda: camera.health["accepted_frames"] == 1)
        now[0] += .3
        assert camera.health["status"] == "STALE" and camera.read_latest() is None
        now[0] += 1.
        assert camera.health["status"] == "TIMEOUT" and camera.read_latest() is None
    finally:
        camera.close()


def test_constructor_and_read_latest_do_not_wait_for_open():
    release = threading.Event()
    capture = Capture()
    def delayed_factory(index, backend):
        release.wait(2.)
        return capture
    started = time.monotonic()
    camera = CameraProvider(capture_factory=delayed_factory)
    assert time.monotonic() - started < .5
    assert camera.read_latest() is None
    release.set()
    camera.close()
    assert capture.released.is_set()


def test_capture_exception_is_visible():
    def broken_factory(index, backend):
        raise RuntimeError("test open failure")
    camera = CameraProvider(capture_factory=broken_factory)
    try:
        wait_for(lambda: camera.health["status"] == "CAPTURE_ERROR")
        assert camera.read_latest() is None
    finally:
        camera.close()
