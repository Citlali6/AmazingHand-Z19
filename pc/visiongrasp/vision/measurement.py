"""Independent table check points and physical setup records; no device I/O."""
from __future__ import annotations

from datetime import datetime, timezone
import math
import uuid

import numpy as np


def check_points(calibration, image_points, table_points, mean_limit_mm=5., max_limit_mm=10.):
    """Checks never enter fit(). Coverage: centre plus all four outer quadrants.

    Coverage is measured in the bounding box of the fitted table ROI. It is a
    sampling rule, not proof of camera distortion correction or physical truth.
    """
    uv, xy = np.asarray(image_points, float), np.asarray(table_points, float)
    if uv.ndim != 2 or uv.shape[1:] != (2,) or uv.shape != xy.shape or len(uv) < 5:
        raise ValueError("at least five independent paired check points required")
    if not np.isfinite(uv).all() or not np.isfinite(xy).all():
        raise ValueError("check points must be finite")
    for values, fitted, separation in ((uv, calibration.image_points, 1.), (xy, calibration.table_points, .1)):
        distances = np.linalg.norm(values[:, None] - values[None, :], axis=2)
        np.fill_diagonal(distances, np.inf)
        if np.any(distances < separation):
            raise ValueError("duplicate or near-duplicate check points")
        if np.any(np.linalg.norm(values[:, None] - fitted[None, :], axis=2) < separation):
            raise ValueError("check points must be independent of fit points")
    limits = (mean_limit_mm, max_limit_mm)
    if any(type(v) not in (int, float) or not math.isfinite(v) or v <= 0 for v in limits):
        raise ValueError("positive finite check error limits required")
    lo, hi = calibration.table_points.min(axis=0), calibration.table_points.max(axis=0)
    normalized = (xy - lo) / (hi - lo)
    centre = np.any(np.all((normalized >= .35) & (normalized <= .65), axis=1))
    corners = all(np.any((normalized[:, 0] < .35 if x == 0 else normalized[:, 0] > .65)
                         & (normalized[:, 1] < .35 if y == 0 else normalized[:, 1] > .65))
                  for x in (0, 1) for y in (0, 1))
    predictions = [calibration.project(p) for p in uv]
    if any(p is None for p in predictions):
        raise ValueError("check point outside fitted ROI")
    # Also reject measured locations outside the table ROI.
    import cv2
    if any(cv2.pointPolygonTest(calibration._table_hull, tuple(p), False) < 0 for p in xy):
        raise ValueError("measured check point outside table ROI")
    errors = np.linalg.norm(np.asarray(predictions) - xy, axis=1)
    mean, rms, maximum = float(errors.mean()), float(np.sqrt(np.mean(errors**2))), float(errors.max())
    return {"image_points": uv.tolist(), "table_points": xy.tolist(),
            "rows": [{"index": i + 1, "uv_px": u.tolist(), "measured_xy_mm": t.tolist(),
                      "predicted_xy_mm": list(p), "error_mm": float(e)}
                     for i, (u, t, p, e) in enumerate(zip(uv, xy, predictions, errors))],
            "mean_mm": mean, "rms_mm": rms, "max_mm": maximum,
            "mean_limit_mm": float(mean_limit_mm), "max_limit_mm": float(max_limit_mm),
            "coverage_ok": bool(centre and corners),
            "passed": bool(centre and corners and mean <= mean_limit_mm and maximum <= max_limit_mm)}


def validate_setup(setup):
    """Require measured geometry and explicit camera/height assumptions."""
    if setup.get("geometry_verified") is not True:
        raise ValueError("geometry must be verified against physical ruler measurements; print design alone is insufficient")
    for name in ("grid_pitch_mm", "board_wh_mm"):
        value = np.asarray(setup[name])
        if value.shape != (2,) or value.dtype.kind not in "fiu" or not np.isfinite(value).all() or np.any(value <= 0):
            raise ValueError(f"measured positive pair required: {name}")
    for name in ("origin_axes", "physical_scale_check", "camera_mount_crop_focus", "distortion_assessment", "object_height_parallax"):
        if not isinstance(setup.get(name), str) or not setup[name].strip():
            raise ValueError(f"physical setup description required: {name}")
    return setup


def measured_calibration(data):
    """Fit training points, then evaluate separate check points without refitting."""
    from .calibration import TableCalibrator
    from visiongrasp.contracts import VisionSource
    setup = validate_setup(data["setup"])
    calibration = TableCalibrator.fit(data["image_points"], data["table_points"], data["frame_wh_px"],
        max_error_mm=data.get("max_fit_error_mm", 2.), source=VisionSource(data["source"]),
        camera_session=data.get("camera_session"), calibration_id=f"table-measured-{uuid.uuid4().hex}")
    checks = data["checks"]
    report = check_points(calibration, checks["image_points"], checks["table_points"],
                          checks.get("mean_limit_mm", 5.), checks.get("max_limit_mm", 10.))
    calibration.measurement = {"version": 1, "created_utc": datetime.now(timezone.utc).isoformat(),
                               "setup": setup, "checks": report}
    return calibration


def restore_measurement(calibration, record):
    if record.get("version") != 1:
        raise ValueError("unsupported measurement metadata")
    datetime.fromisoformat(record["created_utc"])
    validate_setup(record["setup"])
    checks = record["checks"]
    expected = check_points(calibration, checks["image_points"], checks["table_points"],
                            checks["mean_limit_mm"], checks["max_limit_mm"])
    if checks != expected:
        raise ValueError("stored independent check report does not match measurements")
    calibration.measurement = record
