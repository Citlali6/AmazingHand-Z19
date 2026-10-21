"""HSV/contour rules, not neural inference or a grasp-safety guarantee."""
from __future__ import annotations

from dataclasses import dataclass
import math
import time

import cv2
import numpy as np

from visiongrasp.contracts import FramePacket, VisionTarget
from .calibration import TableCalibrator


@dataclass(frozen=True)
class DetectorConfig:
    # OpenCV H=[0,179], S/V=[0,255]; red wraps through hue zero.
    red_ranges: tuple = (((0, 100, 80), (10, 255, 255)), ((170, 100, 80), (179, 255, 255)))
    blue_ranges: tuple = (((95, 100, 80), (135, 255, 255)),)
    min_area_px: float = 250.0
    max_area_fraction: float = 0.25
    min_aspect_ratio: float = 0.7
    max_aspect_ratio: float = 1.4
    min_fill_ratio: float = 0.85
    morphology_kernel: int = 3
    border_margin_px: int = 2

    def __post_init__(self):
        values = (self.min_area_px, self.max_area_fraction, self.min_aspect_ratio,
                  self.max_aspect_ratio, self.min_fill_ratio)
        if not all(math.isfinite(v) and v > 0 for v in values):
            raise ValueError("detector thresholds must be finite and positive")
        if (self.max_area_fraction > 1 or self.min_fill_ratio > 1
                or self.min_aspect_ratio > self.max_aspect_ratio):
            raise ValueError("invalid detector threshold bounds")
        if (type(self.morphology_kernel) is not int or self.morphology_kernel <= 0
                or self.morphology_kernel % 2 != 1 or type(self.border_margin_px) is not int
                or self.border_margin_px < 0):
            raise ValueError("kernel must be positive odd, border margin nonnegative")
        for ranges in (self.red_ranges, self.blue_ranges):
            if not ranges:
                raise ValueError("HSV ranges cannot be empty")
            for low, high in ranges:
                if len(low) != 3 or len(high) != 3:
                    raise ValueError("HSV bounds require triples")
                if any(type(v) is not int for v in (*low, *high)):
                    raise ValueError("HSV bounds must be integers")
                if any(not 0 <= low[i] <= high[i] <= (179 if i == 0 else 255) for i in range(3)):
                    raise ValueError("HSV bound out of range")


class BlockDetector:
    def __init__(self, config=None, max_age_s=0.5, clock=time.monotonic):
        if not math.isfinite(max_age_s) or max_age_s <= 0:
            raise ValueError("max_age_s must be positive")
        self.config = config or DetectorConfig()
        self.max_age_s, self._clock = max_age_s, clock

    def detect(self, packet: FramePacket, calibrator: TableCalibrator | None = None):
        config = self.config
        now = self._clock()
        age = now - packet.capture_monotonic_s
        frame_reason = "STALE" if age > self.max_age_s else "FUTURE_FRAME" if age < 0 else None
        if frame_reason is None and (calibrator is None or calibrator.matrix is None):
            frame_reason = "UNCALIBRATED"
        elif frame_reason is None:
            if not calibrator.validate_frame_size(packet.frame_wh_px):
                frame_reason = "CALIBRATION_SIZE_MISMATCH"
            elif calibrator.source != packet.source:
                frame_reason = "CALIBRATION_SOURCE_MISMATCH"
            elif calibrator.camera_session is not None and calibrator.camera_session != packet.camera_session:
                frame_reason = "CALIBRATION_SESSION_MISMATCH"
        hsv = cv2.cvtColor(packet.image, cv2.COLOR_BGR2HSV)
        kernel = np.ones((config.morphology_kernel, config.morphology_kernel), np.uint8)
        width, height = packet.frame_wh_px
        targets = []
        for label, ranges in (("red_block", config.red_ranges), ("blue_block", config.blue_ranges)):
            mask = np.zeros((height, width), np.uint8)
            for low, high in ranges:
                mask |= cv2.inRange(hsv, np.array(low, np.uint8), np.array(high, np.uint8))
            mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            for contour in contours:
                area = cv2.contourArea(contour)
                if area < config.min_area_px or area > config.max_area_fraction * width * height:
                    continue
                x, y, w, h = cv2.boundingRect(contour)
                ratio = w / h
                rotated_area = float(np.prod(cv2.minAreaRect(contour)[1]))
                fill = area / rotated_area if rotated_area else 0.0
                reason = frame_reason
                if x <= config.border_margin_px or y <= config.border_margin_px or x + w >= width - config.border_margin_px or y + h >= height - config.border_margin_px:
                    reason = reason or "PARTIAL_OBJECT"
                if not config.min_aspect_ratio <= ratio <= config.max_aspect_ratio or fill < config.min_fill_ratio:
                    reason = reason or "SHAPE_REJECTED"
                moments = cv2.moments(contour)
                center = (float(moments["m10"] / moments["m00"]), float(moments["m01"] / moments["m00"]))
                table_xy = calibrator.project(center) if calibrator is not None and reason is None else None
                if reason is None and table_xy is None:
                    reason = "OUT_OF_WORKSPACE"
                targets.append(VisionTarget(
                    camera_session=packet.camera_session, frame_id=packet.frame_id,
                    capture_monotonic_s=packet.capture_monotonic_s, source=packet.source,
                    frame_wh_px=packet.frame_wh_px, object_label=label, center_uv_px=center,
                    table_xy_mm=table_xy, calibration_id=calibrator.calibration_id if calibrator else None,
                    valid=reason is None, rejected_reason=reason,
                    confidence_or_rule_score=min(1.0, fill), bbox_xywh_px=(x, y, w, h)))
        return sorted(targets, key=lambda target: (target.object_label, target.center_uv_px))
