"""Table-plane calibration with manual measured pairs and independent checks."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import cv2
import numpy as np

from visiongrasp.contracts import VisionSource
from visiongrasp.vision import TableCalibrator


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--points", type=Path, help="JSON: image_points, table_points, frame_wh_px, source")
    group.add_argument("--image", type=Path, help="manual clicks on a locally consented image; opens no camera")
    group.add_argument("--live-index", type=int, help="onsite camera-only capture, then freeze for manual clicks")
    parser.add_argument("--measurements", type=Path, help="measured table_points, checks.table_points and setup; click matching pixel points")
    parser.add_argument("--backend", choices=["dshow", "msmf", "any"], default="dshow")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--snapshot", type=Path, help="explicit consent to save original calibration frame locally, new file only")
    parser.add_argument("--table-width-mm", type=float)
    parser.add_argument("--table-height-mm", type=float)
    parser.add_argument("--source", choices=[source.value for source in VisionSource], default="IMAGE_TEST")
    parser.add_argument("--max-error-mm", type=float, default=2.0)
    parser.add_argument("--output", type=Path, required=True, help="new file only; never overwrites calibration")
    args = parser.parse_args(argv)
    from visiongrasp.vision.measurement import measured_calibration
    if args.live_index is not None and args.measurements is None:
        parser.error("live calibration requires --measurements with physical geometry and separate check points")
    if args.points:
        data = json.loads(args.points.read_text(encoding="utf-8"))
        calibration = measured_calibration(data) if "checks" in data else TableCalibrator.fit(data["image_points"], data["table_points"], data["frame_wh_px"],
                                          args.max_error_mm, source=VisionSource(data["source"]),
                                          camera_session=data.get("camera_session"))
    else:
        data = json.loads(args.measurements.read_text(encoding="utf-8")) if args.measurements else None
        if data is not None:
            from visiongrasp.vision.measurement import validate_setup
            validate_setup(data["setup"])
            table = data["table_points"]
            check_table = data["checks"]["table_points"]
            if len(table) < 4 or len(check_table) < 5:
                parser.error("need >=4 fit and >=5 independent check points")
        if data is None and (args.table_width_mm is None or args.table_height_mm is None
                or not np.isfinite([args.table_width_mm, args.table_height_mm]).all()
                or min(args.table_width_mm, args.table_height_mm) <= 0):
            parser.error("interactive mode needs measured positive table width/height in mm")
        packet = None
        if args.live_index is not None:
            from visiongrasp.vision import CameraProvider
            camera = CameraProvider(args.live_index, args.backend, args.width, args.height)
            try:
                deadline = time.monotonic() + 5.
                while packet is None and time.monotonic() < deadline:
                    packet = camera.read_latest()
                    time.sleep(.02)
                if packet is None:
                    parser.error(f"no usable camera frame: {camera.health['status']}")
                image = packet.image
            finally:
                camera.close()
        else:
            image = cv2.imdecode(np.fromfile(args.image, dtype=np.uint8), cv2.IMREAD_COLOR)
        if image is None:
            parser.error("cannot decode image")
        if args.snapshot:
            args.snapshot.parent.mkdir(parents=True, exist_ok=True)
            ok, encoded = cv2.imencode(".png", image)
            if not ok:
                parser.error("cannot encode calibration snapshot")
            with args.snapshot.open("xb") as stream:
                stream.write(encoded.tobytes())
        if data is None:
            table = [(0., 0.), (args.table_width_mm, 0.),
                     (args.table_width_mm, args.table_height_mm), (0., args.table_height_mm)]
            check_table = []
        labels = [("FIT", p) for p in table] + [("CHECK", p) for p in check_table]
        points = []
        print("Click the displayed FIT/CHECK measured coordinate in order. ENTER evaluates; R resets; ESC cancels.")
        cv2.namedWindow("Table calibration")
        cv2.setMouseCallback("Table calibration", lambda event, x, y, flags, param:
                             points.append((x, y)) if event == cv2.EVENT_LBUTTONDOWN and len(points) < len(labels)
                             and all(np.linalg.norm(np.asarray((x, y)) - p) >= 1 for p in points) else None)
        try:
            while True:
                preview = image.copy()
                for index, point in enumerate(points):
                    cv2.circle(preview, point, 5, (0, 255, 0), -1)
                    cv2.putText(preview, f"{labels[index][0]} {index+1}", point, cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
                if points:
                    cv2.polylines(preview, [cv2.convexHull(np.asarray(points[:len(table)], np.int32))], True, (0, 255, 0), 1)
                prompt = f"Next {len(points)+1}: {labels[len(points)]}" if len(points) < len(labels) else "ENTER: evaluate / R: reset / ESC: cancel"
                cv2.putText(preview, prompt, (10, 25), cv2.FONT_HERSHEY_SIMPLEX, .6, (0, 255, 255), 2)
                cv2.imshow("Table calibration", preview)
                key = cv2.waitKey(20) & 0xFF
                if key == 27:
                    return 1
                if key == ord("r"):
                    points.clear()
                if key in (10, 13) and len(points) == len(labels):
                    break
        finally:
            cv2.destroyAllWindows()
        if data is not None:
            data.update(image_points=points[:len(table)], frame_wh_px=[image.shape[1], image.shape[0]],
                        source=packet.source.value if packet else args.source,
                        camera_session=packet.camera_session if packet else None)
            data["checks"]["image_points"] = points[len(table):]
            calibration = measured_calibration(data)
        else:
            calibration = TableCalibrator.fit(points, table, (image.shape[1], image.shape[0]),
                                          args.max_error_mm, source=VisionSource(args.source))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    calibration.save(args.output)
    print(json.dumps({"calibration_id": calibration.calibration_id,
                      "error_mm": calibration.error_mm, "rms_error_mm": calibration.rms_error_mm,
                      "source": calibration.source.value, "robot_base_calibrated": False}))
    if calibration.measurement is not None:
        report = calibration.measurement["checks"]
        print(json.dumps(report, indent=2, allow_nan=False))
        return 0 if report["passed"] else 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
