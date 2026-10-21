import json
from pathlib import Path

import cv2
import pytest

from visiongrasp.app.cli import main
from visiongrasp.contracts import Stage
from visiongrasp.robot import FakeRobot


def read_log(directory):
    paths = list((directory / "logs").glob("*.jsonl"))
    assert len(paths) == 1
    return [json.loads(line) for line in paths[0].read_text().splitlines()]


def test_full_synthetic_camera_detector_calibration_fake_and_dashboard(tmp_path):
    snapshot = tmp_path / "界面.png"
    assert main(["--camera", "synthetic", "--synthetic-calibrated", "--headless",
                 "--auto-run", "--frames", "100", "--output", str(tmp_path),
                 "--snapshot", str(snapshot)]) == 0
    rows = read_log(tmp_path)
    assert len([row for row in rows if row["event"] == "STAGE_RESULT"]) == 7
    assert any(row["event"] == "MOCK_SEQUENCE_COMPLETED" for row in rows)
    assert all(row["robot_source"] == "FAKE" and row["robot_xyz_mm"] is None for row in rows)
    assert snapshot.read_bytes().startswith(b"\x89PNG")


def test_missing_calibration_never_autoruns(tmp_path):
    assert main(["--headless", "--auto-run", "--frames", "2", "--output", str(tmp_path)]) == 2
    assert not any(row["event"] == "STAGE_REQUEST" for row in read_log(tmp_path))


@pytest.mark.parametrize("arguments", [
    ["--camera", "live"],
    ["--camera", "live", "--camera-index", "0", "--auto-run"],
    ["--camera", "live", "--camera-index", "0", "--synthetic-calibrated"],
    ["--mode", "real"], ["--headless", "--frames", "0"],
])
def test_unsafe_or_unbounded_cli_is_rejected_before_device_creation(arguments):
    with pytest.raises(SystemExit) as exc:
        main(arguments)
    assert exc.value.code == 2


def test_fault_does_not_count_failed_stage_as_completed(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr("visiongrasp.robot.FakeRobot",
                        lambda: FakeRobot(stage_delay_s=0, fault_stage=Stage.GRIP))
    assert main(["--headless", "--auto-run", "--synthetic-calibrated", "--frames", "20",
                 "--output", str(tmp_path)]) == 2
    state = json.loads(capsys.readouterr().out)
    assert state["completed_stages"] == 2
    assert state["status"] == "FAULT"
    assert not any(row["event"] == "MOCK_SEQUENCE_COMPLETED" for row in read_log(tmp_path))


def virtual_window(monkeypatch, on_show):
    callbacks = {}
    monkeypatch.setattr(cv2, "namedWindow", lambda *args: None)
    monkeypatch.setattr(cv2, "resizeWindow", lambda *args: None)
    monkeypatch.setattr(cv2, "setMouseCallback", lambda name, callback: callbacks.update(mouse=callback))
    monkeypatch.setattr(cv2, "imshow", lambda name, image: on_show(callbacks["mouse"]))
    monkeypatch.setattr(cv2, "waitKey", lambda *args: 13)
    monkeypatch.setattr(cv2, "getWindowProperty", lambda *args: 1)
    monkeypatch.setattr(cv2, "destroyWindow", lambda *args: None)


def test_calibration_blocks_button_and_keyboard_confirmation(tmp_path, monkeypatch):
    shown = []
    def on_show(mouse):
        if not shown:
            shown.append(True)
            mouse(cv2.EVENT_LBUTTONDOWN, 250, 345, 0, None)  # actual red block on rendered canvas
            mouse(cv2.EVENT_LBUTTONDOWN, 900, 315, 0, None)  # calibration
            mouse(cv2.EVENT_LBUTTONDOWN, 900, 185, 0, None)  # run must stay disabled
    virtual_window(monkeypatch, on_show)
    assert main(["--synthetic-calibrated", "--frames", "2", "--output", str(tmp_path)]) == 2
    rows = read_log(tmp_path)
    assert any(row["event"] == "TARGET_SELECTED" for row in rows)
    assert not any(row["event"] == "STAGE_REQUEST" for row in rows)


def test_gui_fault_returns_failure_without_autorun_option(tmp_path, monkeypatch):
    monkeypatch.setattr("visiongrasp.robot.FakeRobot",
                        lambda: FakeRobot(stage_delay_s=0, fault_stage=Stage.PREPARE))
    shown = []
    def on_show(mouse):
        if not shown:
            shown.append(True)
            mouse(cv2.EVENT_LBUTTONDOWN, 250, 345, 0, None)
            mouse(cv2.EVENT_LBUTTONDOWN, 900, 185, 0, None)
    virtual_window(monkeypatch, on_show)
    assert main(["--synthetic-calibrated", "--frames", "3", "--output", str(tmp_path)]) == 2


def test_failed_camera_is_reported_and_released_without_physical_access(tmp_path, monkeypatch):
    class FailedCamera:
        health = {"status": "OPEN_FAILED", "error": "injected failure"}
        closed = False
        def read_latest(self):
            return None
        def close(self):
            self.closed = True
    camera = FailedCamera()
    monkeypatch.setattr("visiongrasp.vision.CameraProvider", lambda **kwargs: camera)
    assert main(["--camera", "live", "--camera-index", "9", "--headless", "--frames", "2",
                 "--output", str(tmp_path)]) == 2
    assert camera.closed
    assert any(row["event"] == "CAMERA_HEALTH" and row["health"]["status"] == "OPEN_FAILED"
               for row in read_log(tmp_path))
