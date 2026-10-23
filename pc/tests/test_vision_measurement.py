from dataclasses import replace
import importlib.util
import json
from pathlib import Path
import time

import cv2
import numpy as np
import pytest

from visiongrasp.contracts import FramePacket, VisionSource
from visiongrasp.vision import BlockDetector, TableCalibrator
from visiongrasp.vision.measurement import measured_calibration
from visiongrasp.vision.robot_base import BaseCalibration, preview_target


@pytest.fixture
def measurements():
    # Explicit synthetic fixture; never supplied as onsite measurements.
    return {"source": "SYNTHETIC", "frame_wh_px": [640, 480],
        "image_points": [[20, 20], [620, 20], [620, 460], [20, 460]],
        "table_points": [[0, 0], [300, 0], [300, 220], [0, 220]],
        "setup": {"geometry_verified": True, "physical_scale_check": "synthetic test, no physical measurements",
                  "grid_pitch_mm": [20, 20], "board_wh_mm": [300, 220],
                  "origin_axes": "synthetic top-left +x right +y down",
                  "camera_mount_crop_focus": "synthetic fixed image",
                  "distortion_assessment": "synthetic no distortion",
                  "object_height_parallax": "synthetic planar fixture only"},
        "checks": {"image_points": [[80, 64], [560, 64], [560, 416], [80, 416], [320, 240]],
                   "table_points": [[30, 22], [270, 22], [270, 198], [30, 198], [150, 110]]}}


def base_for(cal, **changes):
    data = dict(calibration_id="synthetic-base", table_calibration_id=cal.calibration_id,
        measured_on_site=True, translation_xy_mm=(100, -100), yaw_deg=90., surface_z_mm=-20.,
        object_height_mm=20., contact_height_mm=10., endpoint_to_contact_base_mm=(0, 0, -5),
        approach_posture="synthetic fixed approach only", approach_clearance_mm=40.,
        table_roi_xyxy_mm=(0, 0, 300, 220), robot_bounds_xyz_mm=((-500, 500), (-500, 500), (-100, 300)),
        base_error_mm=1., tool_error_mm=1., parallax_error_mm=1., allowed_error_mm=10.)
    data.update(changes)
    return BaseCalibration(**data)


def frame_at(x=300, y=200, source=VisionSource.SYNTHETIC):
    image = np.full((480, 640, 3), 40, np.uint8)
    cv2.rectangle(image, (x-20, y-20), (x+20, y+20), (0, 0, 255), -1)
    return FramePacket(image, "synthetic-session", x, time.monotonic(), source, (640, 480))


def test_independent_report_and_persistence(measurements, tmp_path):
    cal = measured_calibration(measurements)
    report = cal.measurement["checks"]
    assert report["passed"] and report["coverage_ok"]
    assert report["max_mm"] < 1e-5
    assert len(report["rows"]) == 5
    assert len(cal.image_points) == 4  # check points never enter fit
    path = tmp_path / "cal.json"
    cal.save(path)
    loaded = TableCalibrator.load(path)
    assert loaded.measurement == cal.measurement
    with pytest.raises(FileExistsError):
        cal.save(path)
    data = json.loads(path.read_text())
    data["measurement"]["checks"]["mean_mm"] += 1
    path.write_text(json.dumps(data))
    with pytest.raises(ValueError, match="independent check"):
        TableCalibrator.load(path)


def test_live_four_point_fit_alone_is_not_independent_validation(measurements):
    cal = TableCalibrator.fit(measurements["image_points"], measurements["table_points"], (640, 480),
                              source=VisionSource.LIVE_PC_UVC)
    targets = BlockDetector().detect(frame_at(source=VisionSource.LIVE_PC_UVC), cal)
    assert targets and all(not t.valid and t.table_xy_mm is None
                           and t.rejected_reason == "INDEPENDENT_CHECKS_REQUIRED" for t in targets)


def test_print_design_does_not_count_as_physical_measurement(measurements):
    measurements["setup"]["geometry_verified"] = False
    with pytest.raises(ValueError, match="physical ruler"):
        measured_calibration(measurements)


@pytest.mark.parametrize("failure", ["fit_reuse", "duplicate", "nonfinite", "too_few", "outside", "missing_setup"])
def test_bad_measurements_rejected(measurements, failure):
    if failure == "fit_reuse":
        measurements["checks"]["image_points"][0] = measurements["image_points"][0]
    elif failure == "duplicate":
        measurements["checks"]["table_points"][1] = measurements["checks"]["table_points"][0]
    elif failure == "nonfinite":
        measurements["checks"]["image_points"][0][0] = float("nan")
    elif failure == "too_few":
        measurements["checks"]["image_points"].pop()
        measurements["checks"]["table_points"].pop()
    elif failure == "outside":
        measurements["checks"]["image_points"][0] = [0, 0]
    else:
        measurements["setup"]["origin_axes"] = ""
    with pytest.raises(ValueError):
        measured_calibration(measurements)


@pytest.mark.parametrize("kind", ["error", "coverage"])
def test_failed_checks_kept_as_failed_and_detector_rejects(measurements, kind, tmp_path):
    if kind == "error":
        measurements["checks"]["table_points"][0][0] += 20
    else:
        measurements["checks"]["image_points"] = [[240, 160], [280, 160], [320, 160], [360, 160], [400, 160]]
        measurements["checks"]["table_points"] = [[110, 70], [130, 70], [150, 70], [170, 70], [190, 70]]
    cal = measured_calibration(measurements)
    assert cal.error_mm < 1e-5
    assert not cal.measurement["checks"]["passed"]
    path = tmp_path / "failed.json"
    cal.save(path)
    targets = BlockDetector().detect(frame_at(), TableCalibrator.load(path))
    assert targets and all(not t.valid and t.table_xy_mm is None
                           and t.rejected_reason == "INDEPENDENT_CHECK_FAILED" for t in targets)


def test_rigid_transform_offset_height_and_preview_only(measurements, tmp_path):
    cal = measured_calibration(measurements)
    base = base_for(cal)
    path = tmp_path / "base.json"
    base.save(path)
    base = BaseCalibration.load(path)
    target = BlockDetector().detect(frame_at(320, 240), cal)[0]
    result = preview_target(target, cal, base, now=time.monotonic())
    assert result["status"] == "PLAN PREVIEW"
    assert result["candidate_xyz_mm"] == pytest.approx((-10, 50, -5))
    assert result["approach_xyz_mm"] == pytest.approx((-10, 50, 35))
    assert result["robot_xyz_mm"] is None and not result["motion_allowed"]


@pytest.mark.parametrize("changes", [dict(yaw_deg=float("nan")), dict(surface_z_mm=True),
    dict(measured_on_site="true"), dict(units="m"), dict(coordinate_frame="camera"),
    dict(contact_height_mm=21), dict(endpoint_to_contact_base_mm=[0, 0, float("inf")]),
    dict(table_roi_xyxy_mm=[0, 0, 0, 220]), dict(robot_bounds_xyz_mm=[[0, 0]]*3),
    dict(approach_clearance_mm=0), dict(base_error_mm=-1), dict(endpoint_reference="tool_tip")])
def test_base_bad_configuration_rejected(measurements, changes):
    with pytest.raises(ValueError):
        base_for(measured_calibration(measurements), **changes)


@pytest.mark.parametrize("failure,reason", [
    ("missing", "BASE_UNCALIBRATED"), ("not_measured", "BASE_UNCALIBRATED"),
    ("stale", "STALE_TARGET"), ("future", "STALE_TARGET"),
    ("id", "CALIBRATION_MISMATCH"), ("session", "CALIBRATION_MISMATCH"),
    ("size", "CALIBRATION_MISMATCH"), ("source", "CALIBRATION_MISMATCH"),
    ("coordinates", "TARGET_COORDINATES_MISMATCH"), ("budget", "ERROR_BUDGET_EXCEEDED"),
    ("roi", "OUT_OF_TABLE_ROI"), ("envelope", "OUT_OF_ROBOT_ENVELOPE"),
    ("unchecked", "TABLE_CHECKS_UNVERIFIED")])
def test_preview_fail_closed(measurements, failure, reason):
    cal = measured_calibration(measurements)
    target = BlockDetector().detect(frame_at(), cal)[0]
    base, now = base_for(cal), time.monotonic()
    if failure == "missing": base = None
    elif failure == "not_measured": base = replace(base, measured_on_site=False)
    elif failure == "stale": now += 2
    elif failure == "future": now -= 2
    elif failure == "id": base = replace(base, table_calibration_id="old-id")
    elif failure == "session": cal.camera_session = "old-session"
    elif failure == "size": target = replace(target, frame_wh_px=(1280, 720))
    elif failure == "source": target = replace(target, source=VisionSource.LIVE_PC_UVC)
    elif failure == "coordinates": target = replace(target, table_xy_mm=(10, 10))
    elif failure == "budget": base = replace(base, allowed_error_mm=1)
    elif failure == "roi": base = replace(base, table_roi_xyxy_mm=(0, 0, 50, 50))
    elif failure == "envelope": base = replace(base, robot_bounds_xyz_mm=((0, 1), (0, 1), (0, 1)))
    else: cal.measurement = None
    result = preview_target(target, cal, base, now=now)
    assert result["status"] == "BLOCKED" and result["reason"] == reason
    assert result["robot_xyz_mm"] is None and result["candidate_xyz_mm"] is None


def test_three_positions_fake_seven_stages_and_empty_board(measurements, tmp_path):
    from visiongrasp.app.controller import DemoController
    from visiongrasp.robot import FakeRobot
    cal = measured_calibration(measurements)
    base = base_for(cal)
    candidates = []
    with_controller = DemoController(FakeRobot(stage_delay_s=0), tmp_path)
    try:
        for x in (180, 320, 460):
            packet = frame_at(x)
            targets = BlockDetector().detect(packet, cal)
            with_controller.observe(packet, targets)
            assert with_controller.select(0)
            candidates.append(preview_target(targets[0], cal, base, now=time.monotonic())["candidate_xyz_mm"])
            assert with_controller.start(operator_confirmed=True)
            assert with_controller.wait()
            assert with_controller.snapshot()["completed_stages"] == 7
        empty = replace(frame_at(), image=np.full((480, 640, 3), 40, np.uint8))
        assert BlockDetector().detect(empty, cal) == []
        with_controller.observe(empty, [])
        assert not with_controller.start(operator_confirmed=True)
        assert len(set(candidates)) == 3
    finally:
        with_controller.close()


@pytest.mark.parametrize("passed", [True, False])
def test_measured_points_cli_exit_and_saved_table(measurements, tmp_path, passed):
    if not passed:
        measurements["checks"]["table_points"][0][0] += 20
    spec = importlib.util.spec_from_file_location("calibrate_table", Path(__file__).parents[1]/"scripts"/"calibrate_table.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    path, output = tmp_path/"points.json", tmp_path/"table.json"
    path.write_text(json.dumps(measurements))
    assert module.main(["--points", str(path), "--output", str(output)]) == (0 if passed else 2)
    assert TableCalibrator.load(output).measurement["checks"]["passed"] is passed


def test_manual_measured_clicks_and_original_snapshot(measurements, tmp_path, monkeypatch):
    spec = importlib.util.spec_from_file_location("calibrate_clicks", Path(__file__).parents[1]/"scripts"/"calibrate_table.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    image = np.full((480, 640, 3), 40, np.uint8)
    image_path = tmp_path/"source.png"
    image_path.write_bytes(cv2.imencode(".png", image)[1].tobytes())
    pairs = measurements["image_points"] + measurements["checks"]["image_points"]
    callback = []
    monkeypatch.setattr(cv2, "namedWindow", lambda *args: None)
    monkeypatch.setattr(cv2, "destroyAllWindows", lambda: None)
    monkeypatch.setattr(cv2, "setMouseCallback", lambda name, handler: callback.append(handler))
    def show(*args):
        if pairs:
            u, v = pairs.pop(0)
            callback[0](cv2.EVENT_LBUTTONDOWN, u, v, 0, None)
            callback[0](cv2.EVENT_LBUTTONDOWN, u, v, 0, None)  # duplicate click ignored
    monkeypatch.setattr(cv2, "imshow", show)
    monkeypatch.setattr(cv2, "waitKey", lambda *args: 13)
    path, output, snapshot = tmp_path/"measurements.json", tmp_path/"table.json", tmp_path/"original.png"
    path.write_text(json.dumps(measurements))
    assert module.main(["--image", str(image_path), "--source", "SYNTHETIC", "--measurements", str(path),
                        "--snapshot", str(snapshot), "--output", str(output)]) == 0
    cal = TableCalibrator.load(output)
    assert cal.measurement["checks"]["passed"] and len(cal.image_points) == 4
    assert np.array_equal(cv2.imdecode(np.fromfile(snapshot, np.uint8), cv2.IMREAD_COLOR), image)


@pytest.mark.parametrize("confirmed", [True, False])
def test_live_demo_measurement_binding_and_frame_log(measurements, tmp_path, monkeypatch, confirmed):
    from visiongrasp.app.cli import main
    measurements["source"] = "LIVE_PC_UVC"
    cal = measured_calibration(measurements)
    path = tmp_path/"table.json"
    cal.save(path)
    class InjectedCamera:
        health = {"status": "CAMERA_OK"}
        def read_latest(self): return frame_at(source=VisionSource.LIVE_PC_UVC)
        def close(self): pass
    monkeypatch.setattr("visiongrasp.vision.CameraProvider", lambda **kwargs: InjectedCamera())
    args = ["--camera", "live", "--camera-index", "9", "--headless", "--frames", "2",
            "--calibration", str(path), "--output", str(tmp_path)]
    if confirmed: args.append("--confirm-calibration-setup")
    main(args)
    rows = [json.loads(line) for log in (tmp_path/"logs").glob("*.jsonl") for line in log.read_text().splitlines()]
    vision = [r for r in rows if r["event"] == "VISION_FRAME"]
    assert vision and all(r["valid"] is confirmed and r["source"] == "LIVE_PC_UVC" for r in vision)
    assert all(r["robot_xyz_mm"] is None for r in rows)
    assert not any(r["event"] == "STAGE_REQUEST" for r in rows)
