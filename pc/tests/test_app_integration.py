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


def track_controller(monkeypatch):
    from visiongrasp.app import cli
    original = cli.DemoController
    controllers = []
    def create(*args, **kwargs):
        controller = original(*args, **kwargs)
        controllers.append(controller)
        return controller
    monkeypatch.setattr(cli, "DemoController", create)
    return controllers


def click(mouse, x, y):
    mouse(cv2.EVENT_LBUTTONDOWN, x, y, 0, None)


def cache_camera_frame(monkeypatch):
    from visiongrasp.vision import SyntheticCamera
    class CachedCamera:
        def __init__(self, *args, **kwargs):
            self.camera = SyntheticCamera(*args, **kwargs)
            self.packet = self.camera.read_latest()
        @property
        def health(self):
            return self.camera.health
        def read_latest(self):
            return self.packet
        def close(self):
            self.camera.close()
    monkeypatch.setattr("visiongrasp.vision.SyntheticCamera", CachedCamera)


@pytest.mark.parametrize("failure", ["degenerate_points", "missing_dimensions", "save_failed", "cached_frame"])
def test_failed_recalibration_never_reuses_previous_calibration(tmp_path, monkeypatch, failure):
    controllers = track_controller(monkeypatch)
    if failure == "cached_frame":
        cache_camera_frame(monkeypatch)
    if failure == "save_failed":
        def failed_save(self, path):
            raise OSError("injected calibration persistence failure")
        monkeypatch.setattr("visiongrasp.vision.TableCalibrator.save", failed_save)
    shown = []
    def on_show(mouse):
        controller = controllers[0]
        if not shown:
            assert any(target.valid for target in controller.targets)
            click(mouse, 250, 345)
            assert controller.selected.calibration_id == "synthetic-table-fixture"
            click(mouse, 900, 315)
            points = [(100, 150)] * 4 if failure in ("degenerate_points", "cached_frame") else [
                (50, 140), (750, 140), (750, 670), (50, 670)]
            for point in points:
                click(mouse, *point)
        else:
            # Includes --synthetic-calibrated: startup fixtures must not come back.
            assert controller.targets
            assert all(not target.valid and target.rejected_reason == "UNCALIBRATED"
                       and target.calibration_id is None for target in controller.targets)
            click(mouse, 250, 345)
            click(mouse, 900, 185)
        shown.append(True)
    virtual_window(monkeypatch, on_show)
    monkeypatch.setattr(cv2, "waitKey", lambda *args: -1)
    args = ["--synthetic-calibrated", "--frames", "3", "--output", str(tmp_path)]
    if failure != "missing_dimensions":
        args += ["--table-width-mm", "300", "--table-height-mm", "200"]
    assert main(args) == 2
    rows = read_log(tmp_path)
    assert not any(row["event"] == "STAGE_REQUEST" for row in rows)
    assert any(row["event"] == "TABLE_CALIBRATION_FAILED" for row in rows)
    assert len([row for row in rows if row["event"] == "SYNTHETIC_TABLE_FIXTURE"]) == 1
    assert controllers[0].selected is None or not controllers[0].selected.valid


@pytest.mark.parametrize("cached, automatic_startup", [(False, False), (True, False), (False, True)])
def test_successful_recalibration_requires_new_selection_and_confirmation(tmp_path, monkeypatch, cached, automatic_startup):
    controllers = track_controller(monkeypatch)
    if cached:
        cache_camera_frame(monkeypatch)
    monkeypatch.setattr("visiongrasp.robot.FakeRobot", lambda: FakeRobot(stage_delay_s=0))
    shown = []
    calibration_ids = []
    def on_show(mouse):
        controller = controllers[0]
        step = len(shown)
        if step == 0:
            click(mouse, 250, 345)
            calibration_ids.append(controller.selected.calibration_id)
            click(mouse, 900, 315)
            for point in [(50, 140), (750, 140), (750, 670), (50, 670)]:
                click(mouse, *point)
            assert controller.selected is None
        elif step == 1:
            calibration_ids.append(controller.targets[0].calibration_id)
            assert calibration_ids[1] and calibration_ids[1] != calibration_ids[0]
            assert controller.selected is None
            click(mouse, 900, 185)
            assert controller.snapshot()["completed_stages"] == 0
            assert not any(row["event"] == "STAGE_REQUEST" for row in read_log(tmp_path))
        elif step == 2:
            click(mouse, 250, 345)
            assert controller.selected.valid
            assert controller.selected.calibration_id == calibration_ids[1]
            assert not any(row["event"] == "STAGE_REQUEST" for row in read_log(tmp_path))
        elif step == 3:
            click(mouse, 900, 185)
        shown.append(True)
    virtual_window(monkeypatch, on_show)
    monkeypatch.setattr(cv2, "waitKey", lambda *args: -1)
    args = ["--frames", "8", "--output", str(tmp_path),
            "--table-width-mm", "300", "--table-height-mm", "200"]
    args += ["--auto-run"] if automatic_startup else ["--synthetic-calibrated"]
    assert main(args) == 0
    rows = read_log(tmp_path)
    requests = [row for row in rows if row["event"] == "STAGE_REQUEST"]
    assert len(requests) == 7
    assert all(row["calibration_id"] == calibration_ids[1] for row in requests)
    assert all(row["robot_source"] == "FAKE" and row["robot_xyz_mm"] is None for row in requests)
