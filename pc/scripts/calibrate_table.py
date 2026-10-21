"""Table-plane calibration from measured JSON or four manual image clicks."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

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
    parser.add_argument("--table-width-mm", type=float)
    parser.add_argument("--table-height-mm", type=float)
    parser.add_argument("--source", choices=[source.value for source in VisionSource], default="IMAGE_TEST")
    parser.add_argument("--max-error-mm", type=float, default=2.0)
    parser.add_argument("--output", type=Path, required=True, help="new file only; never overwrites calibration")
    args = parser.parse_args(argv)
    if args.points:
        data = json.loads(args.points.read_text(encoding="utf-8"))
        calibration = TableCalibrator.fit(data["image_points"], data["table_points"], data["frame_wh_px"],
                                          args.max_error_mm, source=VisionSource(data["source"]),
                                          camera_session=data.get("camera_session"))
    else:
        if (args.table_width_mm is None or args.table_height_mm is None
                or not np.isfinite([args.table_width_mm, args.table_height_mm]).all()
                or min(args.table_width_mm, args.table_height_mm) <= 0):
            parser.error("interactive mode needs measured positive table width/height in mm")
        image = cv2.imdecode(np.fromfile(args.image, dtype=np.uint8), cv2.IMREAD_COLOR)
        if image is None:
            parser.error("cannot decode image")
        points = []
        print("Click measured origin, +X corner, opposite corner, +Y corner. ENTER accepts; R resets; ESC cancels.")
        cv2.namedWindow("Table calibration")
        cv2.setMouseCallback("Table calibration", lambda event, x, y, flags, param:
                             points.append((x, y)) if event == cv2.EVENT_LBUTTONDOWN and len(points) < 4 else None)
        try:
            while True:
                preview = image.copy()
                for index, point in enumerate(points):
                    cv2.circle(preview, point, 5, (0, 255, 0), -1)
                    cv2.putText(preview, str(index), point, cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
                cv2.imshow("Table calibration", preview)
                key = cv2.waitKey(20) & 0xFF
                if key == 27:
                    return 1
                if key == ord("r"):
                    points.clear()
                if key in (10, 13) and len(points) == 4:
                    break
        finally:
            cv2.destroyAllWindows()
        table = [(0., 0.), (args.table_width_mm, 0.),
                 (args.table_width_mm, args.table_height_mm), (0., args.table_height_mm)]
        calibration = TableCalibrator.fit(points, table, (image.shape[1], image.shape[0]),
                                          args.max_error_mm, source=VisionSource(args.source))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    calibration.save(args.output)
    print(json.dumps({"calibration_id": calibration.calibration_id,
                      "error_mm": calibration.error_mm, "rms_error_mm": calibration.rms_error_mm,
                      "source": calibration.source.value, "robot_base_calibrated": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
