from dataclasses import replace

import cv2
import numpy as np
import pytest

from visiongrasp.contracts import FramePacket, VisionSource
from visiongrasp.vision import BlockDetector, DetectorConfig, SyntheticCamera, TableCalibrator


def calibration(source=VisionSource.SYNTHETIC, size=(640, 480), session=None):
    return TableCalibrator.fit([(0., 0.), (639., 0.), (639., 479.), (0., 479.)],
                               [(0., 0.), (639., 0.), (639., 479.), (0., 479.)],
                               size, source=source, camera_session=session)


def packet(image, stamp=10.):
    return FramePacket(image, "camera-test", 1, stamp, VisionSource.SYNTHETIC,
                       (image.shape[1], image.shape[0]))


def test_red_blue_positive_and_metadata():
    frame = SyntheticCamera(clock=lambda: 10.).read_latest()
    targets = BlockDetector(clock=lambda: 10.).detect(frame, calibration())
    assert {target.object_label for target in targets} == {"red_block", "blue_block"}
    assert all(target.valid and target.table_xy_mm == pytest.approx(target.center_uv_px) for target in targets)
    assert all(target.camera_session == frame.camera_session and target.frame_id == 0 for target in targets)
    assert all(target.bbox_xywh_px and target.source == VisionSource.SYNTHETIC for target in targets)


@pytest.mark.parametrize("image", [np.zeros((480, 640, 3), np.uint8),
                                  np.full((480, 640, 3), 255, np.uint8)])
def test_blank_frame_has_no_targets(image):
    assert BlockDetector(clock=lambda: 10.).detect(packet(image), calibration()) == []


def test_wrong_color_noise_and_oversized_background():
    image = np.full((480, 640, 3), 40, np.uint8)
    cv2.rectangle(image, (100, 100), (180, 180), (0, 255, 0), -1)
    cv2.rectangle(image, (250, 100), (255, 105), (0, 0, 255), -1)
    assert BlockDetector(clock=lambda: 10.).detect(packet(image), calibration()) == []
    image[:] = (0, 0, 255)
    assert BlockDetector(clock=lambda: 10.).detect(packet(image), calibration()) == []


@pytest.mark.parametrize("shape,reason", [("half", "SHAPE_REJECTED"),
                                           ("notch", "SHAPE_REJECTED"),
                                           ("circle", "SHAPE_REJECTED"),
                                           ("border", "PARTIAL_OBJECT")])
def test_partial_wrong_shape_rejected(shape, reason):
    image = np.full((480, 640, 3), 40, np.uint8)
    if shape == "circle":
        cv2.circle(image, (150, 150), 40, (0, 0, 255), -1)
    elif shape == "border":
        cv2.rectangle(image, (0, 100), (79, 179), (0, 0, 255), -1)
    else:
        cv2.rectangle(image, (100, 100), (179, 179), (0, 0, 255), -1)
        if shape == "half":
            image[100:180, 100:140] = 40
        else:
            image[100:145, 100:145] = 40
    targets = BlockDetector(clock=lambda: 10.).detect(packet(image), calibration())
    assert targets and all(not t.valid and t.rejected_reason == reason for t in targets)


def test_uncalibrated_candidates_never_gain_fake_xyz():
    frame = SyntheticCamera(clock=lambda: 10.).read_latest()
    targets = BlockDetector(clock=lambda: 10.).detect(frame)
    assert len(targets) == 2
    assert all(not t.valid and t.table_xy_mm is None and t.calibration_id is None
               and t.rejected_reason == "UNCALIBRATED" for t in targets)


@pytest.mark.parametrize("age,reason", [(1., "STALE"), (-0.1, "FUTURE_FRAME")])
def test_timestamps_fail_closed(age, reason):
    frame = SyntheticCamera(clock=lambda: 10.).read_latest()
    targets = BlockDetector(clock=lambda: 10. + age).detect(frame, calibration())
    assert all(not t.valid and t.rejected_reason == reason for t in targets)


@pytest.mark.parametrize("kind,reason", [("size", "CALIBRATION_SIZE_MISMATCH"),
                                         ("source", "CALIBRATION_SOURCE_MISMATCH"),
                                         ("session", "CALIBRATION_SESSION_MISMATCH")])
def test_calibration_binding_rejections(kind, reason):
    frame = SyntheticCamera(clock=lambda: 10.).read_latest()
    fitted = calibration(size=(1280, 720) if kind == "size" else (640, 480),
                         source=VisionSource.IMAGE_TEST if kind == "source" else VisionSource.SYNTHETIC,
                         session="different-session" if kind == "session" else None)
    targets = BlockDetector(clock=lambda: 10.).detect(frame, fitted)
    assert all(not t.valid and t.rejected_reason == reason for t in targets)


def test_outside_workspace_rejected():
    fitted = TableCalibrator.fit([(1., 1.), (30., 1.), (30., 30.), (1., 30.)],
                                 [(0., 0.), (29., 0.), (29., 29.), (0., 29.)],
                                 (640, 480), source=VisionSource.SYNTHETIC)
    frame = SyntheticCamera(clock=lambda: 10.).read_latest()
    targets = BlockDetector(clock=lambda: 10.).detect(frame, fitted)
    assert targets and all(not t.valid and t.rejected_reason == "OUT_OF_WORKSPACE" for t in targets)


def test_hue_wrap_and_tunable_thresholds():
    hsv = np.zeros((480, 640, 3), np.uint8)
    hsv[100:180, 100:180] = (175, 240, 240)
    image = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)
    frame = packet(image)
    assert BlockDetector(clock=lambda: 10.).detect(frame, calibration())[0].valid
    config = replace(DetectorConfig(), red_ranges=(((0, 100, 80), (10, 255, 255)),))
    assert BlockDetector(config, clock=lambda: 10.).detect(frame, calibration()) == []


@pytest.mark.parametrize("kwargs", [{"morphology_kernel": 2}, {"min_area_px": -1},
                                    {"blue_ranges": (((180, 0, 0), (255, 255, 255)),)},
                                    {"min_fill_ratio": float("nan")}])
def test_bad_detector_settings_rejected(kwargs):
    with pytest.raises(ValueError):
        DetectorConfig(**kwargs)
