import json

import numpy as np
import pytest

from visiongrasp.contracts import VisionSource
from visiongrasp.vision import TableCalibrator


PIXELS = [(20., 20.), (620., 20.), (620., 460.), (20., 460.)]
TABLE = [(0., 0.), (300., 0.), (300., 220.), (0., 220.)]


def test_unfitted_calibrator_cannot_produce_coordinates_or_save(tmp_path):
    calibration = TableCalibrator()
    assert calibration.project((100., 100.)) is None
    assert not calibration.validate_frame_size((640, 480))
    with pytest.raises(ValueError, match="uncalibrated"):
        calibration.save(tmp_path / "invalid.json")


def test_known_mm_projection_and_workspace():
    calibration = TableCalibrator.fit(PIXELS, TABLE, (640, 480))
    assert calibration.project((320., 240.)) == pytest.approx((150., 110.), abs=1e-5)
    assert calibration.error_mm < 1e-5
    for pixel, table in zip(PIXELS, TABLE):
        assert calibration.project(pixel) == pytest.approx(table, abs=1e-5)
    assert calibration.project((1., 1.)) is None
    assert calibration.project((float("nan"), 20.)) is None
    assert calibration.validate_frame_size((640, 480))
    assert not calibration.validate_frame_size((1280, 720))


def test_overdetermined_projection_not_only_training_points():
    pixels = np.asarray(PIXELS + [(320., 240.), (120., 200.)])
    table = (pixels - (20., 20.)) / 2.
    calibration = TableCalibrator.fit(pixels, table, (640, 480))
    assert calibration.project((200., 300.)) == pytest.approx((90., 140.), abs=1e-5)


@pytest.mark.parametrize("pixels,table", [
    (PIXELS[:3], TABLE[:3]),
    ([(0., 0.), (1., 1.), (2., 2.), (3., 3.)], TABLE),
    (PIXELS, [(0., 0.), (1., 1.), (2., 2.), (3., 3.)]),
    (PIXELS[:-1] + [PIXELS[0]], TABLE),
    (PIXELS, TABLE[:-1] + [TABLE[0]]),
    (PIXELS[:-1] + [(float("inf"), 1.)], TABLE),
    (PIXELS[:-1] + [(640., 20.)], TABLE),
    (PIXELS, [TABLE[0], TABLE[2], TABLE[1], TABLE[3]]),
])
def test_degenerate_points_rejected(pixels, table):
    with pytest.raises(ValueError):
        TableCalibrator.fit(pixels, table, (640, 480))


def test_outlier_not_silently_removed():
    with pytest.raises(ValueError, match="error"):
        TableCalibrator.fit(PIXELS + [(320., 240.)], TABLE + [(180., 160.)], (640, 480), max_error_mm=1.)


def test_persistence_revalidates_all_metadata(tmp_path):
    path = tmp_path / "calibration.json"
    original = TableCalibrator.fit(PIXELS, TABLE, (640, 480), source=VisionSource.SYNTHETIC, camera_session="test")
    original.save(path)
    loaded = TableCalibrator.load(path)
    assert loaded.source == VisionSource.SYNTHETIC
    assert loaded.camera_session == "test"
    assert loaded.calibration_id == original.calibration_id
    assert loaded.project((320., 240.)) == pytest.approx((150., 110.))
    with pytest.raises(FileExistsError):
        original.save(path)
    data = json.loads(path.read_text())
    assert data["robot_base_calibrated"] is False
    data["matrix"][0][2] += 10
    path.write_text(json.dumps(data))
    with pytest.raises(ValueError, match="stored calibration"):
        TableCalibrator.load(path)


@pytest.mark.parametrize("key,value", [("version", 99), ("units", "m"), ("robot_base_calibrated", True)])
def test_bad_metadata_rejected(tmp_path, key, value):
    path = tmp_path / "calibration.json"
    TableCalibrator.fit(PIXELS, TABLE, (640, 480)).save(path)
    data = json.loads(path.read_text())
    data[key] = value
    path.write_text(json.dumps(data))
    with pytest.raises(ValueError, match="metadata"):
        TableCalibrator.load(path)
