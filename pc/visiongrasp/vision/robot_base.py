"""Measured planar frame conversion for PLAN PREVIEW only. No robot imports.

This is not IK, collision checking or motion authorization. Official firmware
endpoint and contact point differ; the offset is expressed in robot-base axes
for one measured approach posture, not a freely rotating tool transform.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
import json
import math
from pathlib import Path

import numpy as np


@dataclass(frozen=True)
class BaseCalibration:
    calibration_id: str
    table_calibration_id: str
    measured_on_site: bool
    translation_xy_mm: tuple
    yaw_deg: float
    surface_z_mm: float
    object_height_mm: float
    contact_height_mm: float
    endpoint_to_contact_base_mm: tuple
    approach_posture: str
    approach_clearance_mm: float
    table_roi_xyxy_mm: tuple
    robot_bounds_xyz_mm: tuple  # ((xmin,xmax), (ymin,ymax), (zmin,zmax))
    base_error_mm: float
    tool_error_mm: float
    parallax_error_mm: float
    allowed_error_mm: float
    version: int = 1
    units: str = "mm"
    coordinate_frame: str = "table_xy_to_roarm_base"
    endpoint_reference: str = "official_EEMode0_endpoint"

    def __post_init__(self):
        if (type(self.version) is not int or self.version != 1 or self.units != "mm"
                or self.coordinate_frame != "table_xy_to_roarm_base"
                or self.endpoint_reference != "official_EEMode0_endpoint"):
            raise ValueError("unsupported base calibration frame/units/version")
        if type(self.measured_on_site) is not bool:
            raise ValueError("measured_on_site must be bool")
        for name in ("calibration_id", "table_calibration_id", "approach_posture"):
            if not isinstance(getattr(self, name), str) or not getattr(self, name).strip():
                raise ValueError(f"missing {name}")
        shapes = {"translation_xy_mm": (2,), "endpoint_to_contact_base_mm": (3,),
                  "table_roi_xyxy_mm": (4,), "robot_bounds_xyz_mm": (3, 2)}
        for name, shape in shapes.items():
            value = np.asarray(getattr(self, name))
            if value.shape != shape or value.dtype.kind not in "fiu" or not np.isfinite(value).all():
                raise ValueError(f"invalid finite coordinates: {name}")
            # Own immutable values even when loaded from JSON lists.
            object.__setattr__(self, name, tuple(tuple(float(v) for v in row) for row in value)
                               if value.ndim == 2 else tuple(float(v) for v in value))
        for name in ("yaw_deg", "surface_z_mm", "object_height_mm", "contact_height_mm",
                     "approach_clearance_mm", "base_error_mm", "tool_error_mm", "parallax_error_mm", "allowed_error_mm"):
            value = getattr(self, name)
            if type(value) not in (int, float) or not math.isfinite(value):
                raise ValueError(f"invalid finite scalar: {name}")
        if not 0 <= self.contact_height_mm <= self.object_height_mm:
            raise ValueError("contact height must lie within measured object height")
        if self.approach_clearance_mm <= 0 or self.allowed_error_mm <= 0 or min(
                self.base_error_mm, self.tool_error_mm, self.parallax_error_mm) < 0:
            raise ValueError("invalid clearance/error budget")
        x0, y0, x1, y1 = self.table_roi_xyxy_mm
        if x0 >= x1 or y0 >= y1 or any(lo >= hi for lo, hi in self.robot_bounds_xyz_mm):
            raise ValueError("invalid ROI/workspace bounds")

    @classmethod
    def load(cls, path):
        return cls(**json.loads(Path(path).read_text(encoding="utf-8")))

    def save(self, path):
        with Path(path).open("x", encoding="utf-8") as stream:
            json.dump(asdict(self), stream, indent=2, allow_nan=False)


def preview_target(target, table_calibration, base=None, *, now, max_age_s=.5):
    """Freshness and error envelopes checked; robot_xyz_mm is always None.

    A candidate endpoint is geometry for human review. Reachability, swept path,
    joints, approach posture and actual grip remain unverified in this module.
    """
    result = {"status": "BLOCKED", "robot_xyz_mm": None, "candidate_xyz_mm": None,
              "approach_xyz_mm": None, "motion_allowed": False, "reason": None,
              "base_calibration_id": base.calibration_id if base else None}
    def reject(reason):
        result["reason"] = reason
        return result
    if type(now) not in (float, int) or not math.isfinite(now) or not math.isfinite(max_age_s) or max_age_s <= 0:
        return reject("INVALID_TIME")
    if target is None or not target.valid or target.table_xy_mm is None:
        return reject("INVALID_TARGET")
    if not 0 <= now - target.capture_monotonic_s <= max_age_s:
        return reject("STALE_TARGET")
    if base is None or not base.measured_on_site:
        return reject("BASE_UNCALIBRATED")
    if (table_calibration is None or target.calibration_id != table_calibration.calibration_id
            or target.calibration_id != base.table_calibration_id
            or target.source != table_calibration.source
            or not table_calibration.validate_frame_size(target.frame_wh_px)
            or (table_calibration.camera_session is not None
                and target.camera_session != table_calibration.camera_session)):
        return reject("CALIBRATION_MISMATCH")
    measurement = table_calibration.measurement
    if measurement is None or not measurement["checks"]["passed"]:
        return reject("TABLE_CHECKS_UNVERIFIED")
    projected = table_calibration.project(target.center_uv_px)
    if projected is None or math.dist(projected, target.table_xy_mm) > 1e-4:
        return reject("TARGET_COORDINATES_MISMATCH")
    error = measurement["checks"]["max_mm"] + base.base_error_mm + base.tool_error_mm + base.parallax_error_mm
    result["error_budget_mm"] = error
    if error > base.allowed_error_mm:
        return reject("ERROR_BUDGET_EXCEEDED")
    x, y = target.table_xy_mm
    x0, y0, x1, y1 = base.table_roi_xyxy_mm
    if not (x0 + error <= x <= x1 - error and y0 + error <= y <= y1 - error):
        return reject("OUT_OF_TABLE_ROI")
    angle = math.radians(base.yaw_deg)
    c, s = math.cos(angle), math.sin(angle)
    contact = (c*x - s*y + base.translation_xy_mm[0],
               s*x + c*y + base.translation_xy_mm[1], base.surface_z_mm + base.contact_height_mm)
    endpoint = tuple(a - b for a, b in zip(contact, base.endpoint_to_contact_base_mm))
    approach = (endpoint[0], endpoint[1], endpoint[2] + base.approach_clearance_mm)
    # Reserve the full conservative error on every axis; endpoint-only checks
    # cannot establish the swept volume or eliminate self collisions.
    for point in (contact, endpoint, approach):
        if not all(math.isfinite(v) and lo + error <= v <= hi - error
                   for v, (lo, hi) in zip(point, base.robot_bounds_xyz_mm)):
            return reject("OUT_OF_ROBOT_ENVELOPE")
    result.update(status="PLAN PREVIEW", candidate_xyz_mm=endpoint, approach_xyz_mm=approach,
                  reason="REACHABILITY_PATH_AND_ONSITE_REVIEW_REQUIRED")
    return result
