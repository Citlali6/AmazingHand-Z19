"""Synthetic/Fake default; live camera is explicit and never selects a serial port."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import time
import uuid

from visiongrasp.contracts import TaskStatus, VisionSource
from .controller import DemoController
from .ui import Dashboard


def parser():
    p = argparse.ArgumentParser(description="PC vision + MOCK ROBOT; no real robot mode")
    p.add_argument("--mode", choices=["mock"], default="mock")
    p.add_argument("--camera", choices=["synthetic", "live"], default="synthetic")
    p.add_argument("--camera-index", type=int)
    p.add_argument("--backend", choices=["dshow", "msmf", "any"], default="dshow")
    p.add_argument("--width", type=int, default=640)
    p.add_argument("--height", type=int, default=480)
    p.add_argument("--headless", action="store_true")
    p.add_argument("--frames", type=int, default=300, help="0: unbounded GUI only")
    p.add_argument("--auto-run", action="store_true", help="Explicit simulated confirmation, synthetic only")
    p.add_argument("--synthetic-calibrated", action="store_true", help="Use a labelled synthetic table fixture")
    p.add_argument("--calibration", type=Path)
    p.add_argument("--confirm-calibration-setup", action="store_true", help="onsite: camera/board/crop/focus unchanged since independent checks")
    p.add_argument("--base-calibration", type=Path, help="measured table-to-base PLAN PREVIEW only; never drives Fake/real robot")
    p.add_argument("--detector-config", type=Path, help="HSV/area/aspect DetectorConfig JSON from camera tuning")
    p.add_argument("--table-width-mm", type=float)
    p.add_argument("--table-height-mm", type=float)
    p.add_argument("--output", type=Path, default=Path("output/pc/demo"))
    p.add_argument("--snapshot", type=Path, help="Explicitly save dashboard; frames otherwise not saved")
    p.add_argument("--max-frame-age-s", type=float, default=.5)
    return p


def main(argv=None) -> int:
    p = parser()
    args = p.parse_args(argv)
    if args.camera == "live" and args.camera_index is None:
        p.error("live camera requires an explicit --camera-index; identify the lab USB camera")
    if args.camera == "live" and (args.auto_run or args.synthetic_calibrated):
        p.error("synthetic fixtures/auto confirmation cannot be used with a live camera")
    if args.frames < 0 or (args.headless and args.frames == 0):
        p.error("headless execution must have a positive frame limit")
    if args.width <= 0 or args.height <= 0:
        p.error("frame dimensions must be positive")
    import cv2
    from visiongrasp.robot import FakeRobot
    from visiongrasp.vision import SyntheticCamera, CameraProvider, BlockDetector, DetectorConfig, TableCalibrator

    camera = None
    controller = None
    window = "VisionGrasp PC | MOCK ROBOT"
    gui_created = False
    exit_code = 0
    calibrator = None
    calibration_points = []
    calibrating = False
    packet = None
    targets = []
    note = "Select a block, then explicitly confirm."
    dashboard = Dashboard()
    canvas = None
    auto_started = False
    auto_run_enabled = args.auto_run
    synthetic_fixture_pending = args.synthetic_calibrated
    detected_calibration_id = None
    setup_bound_session = None
    logged_frame = None
    base_calibration = None
    last_health = None
    try:
        if args.calibration:
            calibrator = TableCalibrator.load(args.calibration)
        if args.base_calibration:
            from visiongrasp.vision.robot_base import BaseCalibration
            base_calibration = BaseCalibration.load(args.base_calibration)
        config = DetectorConfig(**json.loads(args.detector_config.read_text(encoding="utf-8"))) if args.detector_config else DetectorConfig()
        detector = BlockDetector(config, max_age_s=args.max_frame_age_s)
        camera = (SyntheticCamera(args.width, args.height) if args.camera == "synthetic" else
                  CameraProvider(index=args.camera_index, backend=args.backend, width=args.width,
                                 height=args.height, max_age_s=args.max_frame_age_s))
        controller = DemoController(FakeRobot(), args.output / "logs", max_frame_age_s=args.max_frame_age_s)

        def fit_table(points, frame):
            if args.table_width_mm is None or args.table_height_mm is None:
                raise ValueError("Set measured --table-width-mm and --table-height-mm")
            if not args.table_width_mm > 0 or not args.table_height_mm > 0:
                raise ValueError("Measured table dimensions must be positive")
            return TableCalibrator.fit(points, [(0, 0), (args.table_width_mm, 0),
                                       (args.table_width_mm, args.table_height_mm), (0, args.table_height_mm)],
                                       frame.frame_wh_px, source=frame.source,
                                       calibration_id=f"table-{uuid.uuid4()}")

        def mouse(event, x, y, flags, userdata):
            nonlocal calibrator, calibrating, calibration_points, note, targets, synthetic_fixture_pending, auto_run_enabled
            if event != cv2.EVENT_LBUTTONDOWN:
                return
            action = dashboard.action(x, y)
            if action == "run":
                if calibrating:
                    note = "Finish table calibration before confirmation."
                else:
                    controller.start(operator_confirmed=True)
            elif action == "stop":
                controller.stop()
            elif action == "calibrate":
                controller.invalidate_selection()
                previous_id = calibrator.calibration_id if calibrator is not None else None
                calibrator = None
                targets = []
                # A startup fixture must not silently replace a failed manual calibration.
                synthetic_fixture_pending = False
                auto_run_enabled = False
                calibrating = True
                calibration_points = []
                note = "Click TL, TR, BR, BL of measured table."
                controller.log.write("TABLE_CALIBRATION_STARTED", previous_calibration_id=previous_id,
                                     calibration_id=None)
            else:
                point = dashboard.image_point(x, y)
                if point is None or packet is None:
                    return
                if calibrating:
                    calibration_points.append(point)
                    if len(calibration_points) == 4:
                        try:
                            candidate = fit_table(calibration_points, packet)
                            saved = args.output / f"{candidate.calibration_id}.json"
                            candidate.save(saved)
                            calibrator = candidate
                            targets = []
                            controller.invalidate_selection("CALIBRATION_UPDATED")
                            note = "TABLE calibrated. Robot base remains UNCALIBRATED."
                            controller.log.write("TABLE_CALIBRATED", camera_source=packet.source.value,
                                                 calibration_id=calibrator.calibration_id)
                        except (ValueError, OSError, cv2.error) as exc:
                            calibrator = None
                            targets = []
                            controller.invalidate_selection("UNCALIBRATED")
                            note = f"UNCALIBRATED: {exc}"
                            controller.log.write("TABLE_CALIBRATION_FAILED", calibration_id=None,
                                                 error=str(exc))
                        calibrating = False
                else:
                    for i, target in enumerate(targets):
                        if target.bbox_xywh_px:
                            tx, ty, tw, th = target.bbox_xywh_px
                            if tx <= point[0] <= tx + tw and ty <= point[1] <= ty + th:
                                controller.select(i)
                                break

        if not args.headless:
            cv2.namedWindow(window, cv2.WINDOW_NORMAL)
            gui_created = True
            cv2.resizeWindow(window, dashboard.width, dashboard.height)
            cv2.setMouseCallback(window, mouse)
        index = 0
        while args.frames == 0 or index < args.frames:
            previous = packet
            packet = camera.read_latest()
            health = camera.health
            if health["status"] != last_health:
                controller.log.write("CAMERA_HEALTH", camera_source="SYNTHETIC" if args.camera == "synthetic" else "LIVE_PC_UVC",
                                     health=health, monotonic_s=time.monotonic())
                last_health = health["status"]
            if packet is not None and calibrator is None and synthetic_fixture_pending:
                w, h = packet.frame_wh_px
                calibrator = TableCalibrator.fit([(0, 0), (w-1, 0), (w-1, h-1), (0, h-1)],
                    [(0, 0), (300, 0), (300, 200), (0, 200)], packet.frame_wh_px,
                    source=VisionSource.SYNTHETIC, calibration_id="synthetic-table-fixture")
                controller.log.write("SYNTHETIC_TABLE_FIXTURE", calibration_id="synthetic-table-fixture")
                synthetic_fixture_pending = False
            current_calibration_id = calibrator.calibration_id if calibrator is not None else None
            if packet is not None and args.camera == "live" and calibrator is not None:
                if (calibrator.measurement is None or not args.confirm_calibration_setup
                        or not calibrator.measurement["checks"]["passed"]):
                    controller.invalidate_selection("INDEPENDENT_CHECKS_AND_SETUP_CONFIRMATION_REQUIRED")
                    calibrator = None
                    current_calibration_id = None
                elif setup_bound_session is None:
                    # A new camera process has a new session. Explicit onsite setup
                    # confirmation permits binding; source and actual size still checked.
                    old_session = calibrator.camera_session
                    calibrator.camera_session = packet.camera_session
                    setup_bound_session = packet.camera_session
                    controller.log.write("CALIBRATION_SETUP_CONFIRMED", calibration_id=calibrator.calibration_id,
                                         previous_camera_session=old_session, camera_session=setup_bound_session)
                elif setup_bound_session != packet.camera_session:
                    controller.invalidate_selection("CAMERA_SESSION_CHANGED")
                    calibrator = None
                    current_calibration_id = None
            if packet is None:
                targets = []
            elif (previous is None or (packet.camera_session, packet.frame_id) != (previous.camera_session, previous.frame_id)
                  or current_calibration_id != detected_calibration_id):
                targets = detector.detect(packet, calibrator)
                detected_calibration_id = current_calibration_id
            controller.observe(packet, targets)
            frame_identity = (packet.camera_session, packet.frame_id, current_calibration_id) if packet else None
            if frame_identity is not None and frame_identity != logged_frame:
                from dataclasses import asdict
                controller.log.write("VISION_FRAME", source=packet.source.value,
                    camera_session=packet.camera_session, frame_id=packet.frame_id,
                    capture_monotonic_s=packet.capture_monotonic_s, frame_wh_px=packet.frame_wh_px,
                    calibration_id=current_calibration_id, valid=any(t.valid for t in targets),
                    rejected_reason=None if any(t.valid for t in targets) else "NO_VALID_TARGET",
                    targets=[asdict(t) for t in targets])
                logged_frame = frame_identity
            if auto_run_enabled and not auto_started and any(t.valid for t in targets):
                controller.select(next(i for i, t in enumerate(targets) if t.valid))
                auto_started = controller.start(operator_confirmed=True)
            state = controller.snapshot()
            from visiongrasp.vision.robot_base import preview_target
            state["plan_preview"] = preview_target(state["selected"], calibrator, base_calibration,
                                                   now=time.monotonic(), max_age_s=args.max_frame_age_s)
            camera_note = note if health["status"] == "CAMERA_OK" else f"CAMERA: {health['status']}"
            canvas = dashboard.render(packet, targets, state, note=camera_note,
                                      calibration_points=calibration_points if calibrating else (),
                                      table_calibration=calibrator)
            if not args.headless:
                cv2.imshow(window, canvas)
                key = cv2.waitKey(1) & 0xff
                if key in (ord("q"), 27) or cv2.getWindowProperty(window, cv2.WND_PROP_VISIBLE) < 1:
                    break
                if key in (ord("s"), 32):
                    controller.stop()
                elif key in (10, 13):
                    if not calibrating:
                        controller.start(operator_confirmed=True)
            if args.headless and auto_started and state["status"] != TaskStatus.RUNNING.value:
                break
            index += 1
            time.sleep(.01 if args.headless else .02)
        if args.snapshot and canvas is not None:
            args.snapshot.parent.mkdir(parents=True, exist_ok=True)
            ok, encoded = cv2.imencode(".png", canvas)
            if not ok:
                raise OSError("Could not save requested snapshot")
            args.snapshot.write_bytes(encoded.tobytes())
        state = controller.snapshot()
        if state["status"] in (TaskStatus.FAULT.value, TaskStatus.STOP_REQUESTED.value):
            exit_code = 2
        if camera.health["status"] != "CAMERA_OK":
            exit_code = 2
        if auto_run_enabled and (not auto_started or state["completed_stages"] != 7 or state["error"]):
            exit_code = 2
        print(json.dumps({"mode": "MOCK", "camera": args.camera, "robot_xyz_mm": None,
                          "status": state["status"], "completed_stages": state["completed_stages"],
                          "error": state["error"], "log": str(controller.log.path),
                          "hardware": "ROARM NOT TESTED; physical camera NOT VERIFIED"}, indent=2))
    except (ValueError, TypeError, RuntimeError, OSError, cv2.error) as exc:
        print(json.dumps({"mode": "MOCK", "error": f"{type(exc).__name__}: {exc}"}))
        exit_code = 2
    finally:
        try:
            if controller is not None:
                controller.close()
        finally:
            try:
                if camera is not None:
                    camera.close()
            finally:
                if gui_created:
                    cv2.destroyWindow(window)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
