"""Measured image-to-table homography; never a robot-base calibration."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import cv2
import numpy as np

from visiongrasp.contracts import VisionSource


class TableCalibrator:
    VERSION = 1

    def __init__(self):
        self.matrix = None
        self.frame_wh_px = None
        self.calibration_id = None
        self.source = None
        self.camera_session = None
        self.measurement = None

    @classmethod
    def fit(cls, image_points, table_points, frame_wh_px, max_error_mm=2.0,
            calibration_id=None, source=VisionSource.IMAGE_TEST, camera_session=None):
        """Fit all measured correspondences; reject rather than hide outliers.

        Pixel origin is top-left, u right/v down. Table origin and +X/+Y follow
        the supplied measured table_points in mm. Workspace is the convex hull
        of these points. Source prevents synthetic calibration on live footage.
        """
        pixels, table = np.asarray(image_points, dtype=np.float64), np.asarray(table_points, dtype=np.float64)
        if pixels.ndim != 2 or pixels.shape[1:] != (2,) or len(pixels) < 4 or pixels.shape != table.shape:
            raise ValueError("at least four paired 2D points required")
        if not np.isfinite(pixels).all() or not np.isfinite(table).all():
            raise ValueError("calibration points must be finite")
        if (len(frame_wh_px) != 2 or any(type(v) is not int or v <= 0 for v in frame_wh_px)):
            raise ValueError("frame_wh_px must contain positive integers")
        if not isinstance(source, VisionSource):
            raise ValueError("explicit VisionSource required")
        if camera_session is not None and (not isinstance(camera_session, str) or not camera_session.strip()):
            raise ValueError("camera_session must be nonempty or None")
        if not math.isfinite(max_error_mm) or max_error_mm <= 0:
            raise ValueError("max_error_mm must be positive")
        if calibration_id is not None and (not isinstance(calibration_id, str) or not calibration_id.strip()):
            raise ValueError("calibration_id must be nonempty")
        width, height = frame_wh_px
        if np.any(pixels < 0) or np.any(pixels[:, 0] >= width) or np.any(pixels[:, 1] >= height):
            raise ValueError("image calibration points outside frame")
        for points in (pixels, table):
            if len(np.unique(points, axis=0)) != len(points):
                raise ValueError("duplicate calibration point")
            hull = cv2.convexHull(points.astype(np.float32))
            if cv2.contourArea(hull) < 1e-4:
                raise ValueError("degenerate collinear calibration")
        matrix, _ = cv2.findHomography(pixels, table, method=0)
        if matrix is None or not np.isfinite(matrix).all() or np.linalg.matrix_rank(matrix) != 3:
            raise ValueError("degenerate homography")
        # Reject a projective horizon crossing the measured workspace.
        denominator = pixels @ matrix[2, :2] + matrix[2, 2]
        if np.any(np.abs(denominator) < 1e-9) or not (np.all(denominator > 0) or np.all(denominator < 0)):
            raise ValueError("homography crosses projective horizon")
        projected = cv2.perspectiveTransform(pixels[None], matrix)[0]
        errors = np.linalg.norm(projected - table, axis=1)
        if not np.isfinite(errors).all() or np.max(errors) > max_error_mm:
            raise ValueError("calibration reprojection error exceeds max_error_mm")
        # Four arbitrary crossed correspondences can have zero fit residual.
        # Their hull order must stay convex after projection.
        hull_indices = cv2.convexHull(pixels.astype(np.float32), returnPoints=False).reshape(-1)
        if not cv2.isContourConvex(table[hull_indices].astype(np.float32)):
            raise ValueError("crossed or inconsistent calibration correspondences")
        instance = cls()
        instance.image_points, instance.table_points = pixels.copy(), table.copy()
        instance.frame_wh_px = tuple(frame_wh_px)
        instance.matrix = matrix
        instance.max_error_mm = float(max_error_mm)
        instance.error_mm = float(np.max(errors))
        instance.rms_error_mm = float(np.sqrt(np.mean(errors ** 2)))
        instance.source, instance.camera_session = source, camera_session
        instance._image_hull = cv2.convexHull(pixels.astype(np.float32))
        instance._table_hull = cv2.convexHull(table.astype(np.float32))
        digest = hashlib.sha256(json.dumps({"image": pixels.tolist(), "table": table.tolist(),
                                           "size": list(frame_wh_px), "source": source.value,
                                           "session": camera_session}, sort_keys=True).encode()).hexdigest()[:16]
        instance.calibration_id = calibration_id or f"table-v{cls.VERSION}-{digest}"
        return instance

    def validate_frame_size(self, frame_wh_px):
        return self.matrix is not None and tuple(frame_wh_px) == self.frame_wh_px

    def project(self, center_uv_px):
        if self.matrix is None:
            return None
        point = np.asarray(center_uv_px, dtype=np.float64)
        if point.shape != (2,) or not np.isfinite(point).all():
            return None
        if cv2.pointPolygonTest(self._image_hull, tuple(point), False) < 0:
            return None
        denominator = float(self.matrix[2, :2] @ point + self.matrix[2, 2])
        if abs(denominator) < 1e-9:
            return None
        xy = (self.matrix[:2, :2] @ point + self.matrix[:2, 2]) / denominator
        if not np.isfinite(xy).all() or cv2.pointPolygonTest(self._table_hull, tuple(xy), True) < -1e-4:
            return None
        return tuple(float(value) for value in xy)

    def save(self, path):
        if self.matrix is None:
            raise ValueError("cannot save uncalibrated table")
        payload = {"version": self.VERSION, "units": "mm", "coordinate_frame": "table_xy",
                   "axes": "origin/+X/+Y defined by measured table_points; pixel u right, v down",
                   "robot_base_calibrated": False, "calibration_id": self.calibration_id,
                   "source": self.source.value, "camera_session": self.camera_session,
                   "frame_wh_px": self.frame_wh_px,
                   "image_points": self.image_points.tolist(), "table_points": self.table_points.tolist(),
                   "matrix": self.matrix.tolist(), "max_error_mm": self.max_error_mm,
                   "error_mm": self.error_mm, "rms_error_mm": self.rms_error_mm}
        if self.measurement is not None:
            payload["measurement"] = self.measurement
        # Caller owns path selection; refuse to replace an existing calibration.
        with Path(path).open("x", encoding="utf-8") as stream:
            json.dump(payload, stream, indent=2, allow_nan=False)

    @classmethod
    def load(cls, path):
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
        if (payload.get("version") != cls.VERSION or payload.get("units") != "mm"
                or payload.get("coordinate_frame") != "table_xy"
                or payload.get("robot_base_calibrated") is not False):
            raise ValueError("unsupported calibration metadata")
        instance = cls.fit(payload["image_points"], payload["table_points"], payload["frame_wh_px"],
                           payload["max_error_mm"], payload["calibration_id"],
                           VisionSource(payload["source"]), payload.get("camera_session"))
        stored = np.asarray(payload["matrix"], dtype=np.float64)
        if (stored.shape != (3, 3) or not np.isfinite(stored).all()
                or not np.allclose(stored, instance.matrix, rtol=1e-5, atol=1e-6)
                or not math.isclose(payload["error_mm"], instance.error_mm, abs_tol=1e-5)
                or not math.isclose(payload["rms_error_mm"], instance.rms_error_mm, abs_tol=1e-5)):
            raise ValueError("stored calibration does not match measured correspondences")
        if "measurement" in payload:
            from .measurement import restore_measurement
            restore_measurement(instance, payload["measurement"])
        return instance
