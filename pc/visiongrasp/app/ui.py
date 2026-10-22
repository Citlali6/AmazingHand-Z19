"""OpenCV-only dashboard; rendering is testable without creating any windows."""
from __future__ import annotations

import cv2
import numpy as np

from visiongrasp.contracts import MOTION_STAGES


class Dashboard:
    width, height = 1280, 800
    buttons = {"run": (824, 160, 1250, 210), "stop": (824, 225, 1250, 275),
               "calibrate": (824, 290, 1250, 340)}

    def __init__(self):
        self.image_rect = (24, 118, 760, 570)
        self.frame_wh = None

    @staticmethod
    def text(canvas, text, x, y, scale=.55, color=(200, 210, 223), thickness=1):
        cv2.putText(canvas, str(text)[:100], (x, y), cv2.FONT_HERSHEY_SIMPLEX,
                    scale, color, thickness, cv2.LINE_AA)

    def image_point(self, x, y):
        ix, iy, iw, ih = self.image_rect
        if self.frame_wh is None or not (ix <= x < ix + iw and iy <= y < iy + ih):
            return None
        return ((x - ix) * self.frame_wh[0] / iw, (y - iy) * self.frame_wh[1] / ih)

    def action(self, x, y):
        for action, (x1, y1, x2, y2) in self.buttons.items():
            if x1 <= x <= x2 and y1 <= y <= y2:
                return action
        return None

    def render(self, packet, targets, state, *, note="", calibration_points=(), table_calibration=None):
        canvas = np.full((self.height, self.width, 3), (25, 20, 17), np.uint8)
        self.text(canvas, "VISIONGRASP / PC DEMO", 24, 42, .9, (245, 245, 245), 2)
        source = packet.source.value if packet else "NO CAMERA FRAME"
        self.text(canvas, f"{source}  +  MOCK ROBOT", 24, 78, .65, (100, 220, 150), 2)
        self.text(canvas, "LOGICAL STAGE DEMO / NO PHYSICAL GRASP", 824, 78, .43)
        cv2.rectangle(canvas, (18, 108), (798, 700), (50, 58, 67), 1)
        if packet is not None:
            self.frame_wh = packet.frame_wh_px
            fw, fh = self.frame_wh
            ratio = min(760 / fw, 570 / fh)
            rw, rh = max(1, int(fw * ratio)), max(1, int(fh * ratio))
            self.image_rect = (24, 118, rw, rh)
            canvas[118:118 + rh, 24:24 + rw] = cv2.resize(packet.image, (rw, rh))
            if table_calibration is not None and table_calibration.validate_frame_size(packet.frame_wh_px):
                hull = table_calibration._image_hull.reshape(-1, 2)
                mapped = np.array([(24 + int(u*ratio), 118 + int(v*ratio)) for u, v in hull], np.int32)
                cv2.polylines(canvas, [mapped], True, (80, 220, 220), 1)
                for i, (uv, xy) in enumerate(zip(table_calibration.image_points, table_calibration.table_points)):
                    p = (24 + int(uv[0]*ratio), 118 + int(uv[1]*ratio))
                    cv2.circle(canvas, p, 3, (80, 220, 220), -1)
                    self.text(canvas, f"{i+1}: {xy[0]:g},{xy[1]:g} mm", p[0], p[1], .36)
                if table_calibration.measurement is not None:
                    pitch = table_calibration.measurement["setup"]["grid_pitch_mm"]
                    low = table_calibration.table_points.min(axis=0)
                    high = table_calibration.table_points.max(axis=0)
                    counts = np.floor((high-low)/pitch).astype(float)
                    if np.isfinite(counts).all() and np.prod(counts+1) <= 400:
                        inverse = np.linalg.inv(table_calibration.matrix)
                        for x in np.arange(np.ceil(low[0]/pitch[0])*pitch[0], high[0]+1e-6, pitch[0]):
                            for y in np.arange(np.ceil(low[1]/pitch[1])*pitch[1], high[1]+1e-6, pitch[1]):
                                uvw = inverse @ np.array([x, y, 1.])
                                if abs(uvw[2]) < 1e-9:
                                    continue
                                uv = uvw[:2] / uvw[2]
                                if table_calibration.project(uv) is not None:
                                    p = (24+int(uv[0]*ratio), 118+int(uv[1]*ratio))
                                    cv2.circle(canvas, p, 1, (80, 220, 220), -1)
            for index, target in enumerate(targets):
                if target.bbox_xywh_px:
                    x, y, w, h = target.bbox_xywh_px
                    p1, p2 = (24 + int(x * ratio), 118 + int(y * ratio)), (24 + int((x+w) * ratio), 118 + int((y+h) * ratio))
                    selected = state.get("selected") == target
                    color = (120, 235, 145) if target.valid else (60, 185, 245)
                    cv2.rectangle(canvas, p1, p2, color, 3 if selected else 1)
                    self.text(canvas, f"{index + 1}: {target.object_label}", p1[0], max(132, p1[1] - 8), .48, color)
                    if target.table_xy_mm is not None:
                        self.text(canvas, f"{target.table_xy_mm[0]:.1f}, {target.table_xy_mm[1]:.1f} mm",
                                  p1[0], p2[1] + 15, .4, color)
            for point in calibration_points:
                cv2.circle(canvas, (24 + int(point[0]*ratio), 118 + int(point[1]*ratio)), 6, (255, 255, 255), 2)
            self.text(canvas, f"FRAME {packet.frame_id}   {fw} x {fh}   Click a block to select", 24, 724, .47)
        else:
            self.frame_wh = None
            self.text(canvas, "WAITING FOR FRAME", 245, 390, .8, (120, 150, 240))
        for action, label in (("run", "CONFIRM & RUN MOCK"), ("stop", "STOP NEXT STAGES"),
                              ("calibrate", "CALIBRATE: 4 CORNERS")):
            x1, y1, x2, y2 = self.buttons[action]
            color = (62, 57, 49) if action != "stop" else (60, 56, 130)
            cv2.rectangle(canvas, (x1, y1), (x2, y2), color, -1)
            self.text(canvas, label, x1 + 18, y1 + 32, .6, (245, 245, 245), 1)
        self.text(canvas, "ROBOT: MOCK / NO SERIAL CONNECTION", 824, 126, .52, (100, 220, 150), 1)
        self.text(canvas, "STATUS", 824, 383, .44, (140, 155, 175))
        self.text(canvas, state["status"], 824, 417, .8, (245, 245, 245), 2)
        self.text(canvas, f"Stage: {state.get('stage') or '-'}", 824, 455, .58)
        selected = state.get("selected")
        self.text(canvas, f"Target: {selected.object_label if selected else 'SELECT A BLOCK'}", 824, 490, .54)
        uv = f"({selected.center_uv_px[0]:.1f}, {selected.center_uv_px[1]:.1f})" if selected else "-"
        self.text(canvas, f"Pixel uv: {uv}", 824, 522, .51)
        xy = selected.table_xy_mm if selected else None
        xy_text = f"({xy[0]:.1f}, {xy[1]:.1f})" if xy is not None else "UNCALIBRATED"
        self.text(canvas, f"Table mm: {xy_text}", 824, 553, .51)
        preview = state.get("plan_preview") or {}
        candidate = preview.get("candidate_xyz_mm")
        candidate_text = ",".join(f"{v:.1f}" for v in candidate) if candidate else "BLOCKED"
        self.text(canvas, f"PLAN PREVIEW mm: {candidate_text}", 824, 584, .43)
        feedback = state.get("feedback")
        self.text(canvas, f"Feedback: {'FAKE' if feedback else 'NO SAMPLE'}", 824, 614, .5)
        error = state.get("error") or note
        self.text(canvas, str(error)[:48], 824, 640, .46, (100, 175, 255))
        self.text(canvas, "Q: quit   S/SPACE: stop   ENTER: confirm", 824, 679, .42)
        completed = state.get("completed_stages", 0)
        for index, stage in enumerate(MOTION_STAGES):
            x = 24 + index * 177
            color = (80, 165, 100) if index < completed else (65, 60, 52)
            cv2.rectangle(canvas, (x, 749), (x + 164, 785), color, -1)
            self.text(canvas, stage.value, x + 9, 773, .45, (245, 245, 245))
        return canvas
