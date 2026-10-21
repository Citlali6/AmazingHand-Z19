"""Synthetic by default; --live is a manual, on-site USB camera diagnostic."""
from __future__ import annotations

import argparse
from dataclasses import replace
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import cv2

from visiongrasp.vision import BlockDetector, CameraProvider, DetectorConfig, SyntheticCamera, TableCalibrator


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true", help="manually authorize camera opening; never touches serial")
    parser.add_argument("--index", type=int, default=0)
    parser.add_argument("--backend", choices=("dshow", "msmf", "any"), default="dshow")
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--seconds", type=float, default=15)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--tune", action="store_true", help="HSV/area trackbars; changes are not auto-saved")
    parser.add_argument("--config", type=Path, help="DetectorConfig fields as JSON")
    parser.add_argument("--calibration", type=Path)
    parser.add_argument("--output", type=Path, default=Path("output/pc/issue8"))
    args = parser.parse_args(argv)
    if args.seconds <= 0 or args.headless and args.tune:
        parser.error("seconds must be positive; tune requires a window")
    config_data = json.loads(args.config.read_text(encoding="utf-8")) if args.config else {}
    for name in ("red_ranges", "blue_ranges"):
        if name in config_data:
            config_data[name] = tuple((tuple(lo), tuple(hi)) for lo, hi in config_data[name])
    config = DetectorConfig(**config_data)
    detector = BlockDetector(config)
    calibration = TableCalibrator.load(args.calibration) if args.calibration else None
    provider = CameraProvider(args.index, args.backend, args.width, args.height) if args.live else SyntheticCamera(args.width, args.height)
    mode = "LIVE_PC_UVC / NO ROBOT" if args.live else "SYNTHETIC / NO ROBOT"
    print(mode, flush=True)
    print("Rule detector; table plane only. Robot base and grasp Z: UNCALIBRATED / None.", flush=True)
    args.output.mkdir(parents=True, exist_ok=True)
    path = args.output / ("camera-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + ".jsonl")
    started, last_print = time.monotonic(), 0.0
    saw_frame, last_identity = False, None
    try:
        with path.open("x", encoding="utf-8") as log:
            if not args.headless:
                cv2.namedWindow("VisionGrasp camera")
            if args.tune:
                cv2.namedWindow("HSV rules")
                controls = (("red H low", 0, 179), ("red H high", 10, 179),
                            ("red wrap low", 170, 179), ("red wrap high", 179, 179),
                            ("blue H low", 95, 179), ("blue H high", 135, 179),
                            ("S min", 100, 255), ("V min", 80, 255), ("area min", 250, 10000))
                for name, value, maximum in controls:
                    cv2.createTrackbar(name, "HSV rules", value, maximum, lambda value: None)
            while time.monotonic() - started < args.seconds:
                packet = provider.read_latest()
                now = time.monotonic()
                health = provider.health
                if packet is not None:
                    saw_frame = True
                    if args.tune:
                        get = lambda name: cv2.getTrackbarPos(name, "HSV rules")
                        sat, val = get("S min"), get("V min")
                        red_lo, red_hi = sorted((get("red H low"), get("red H high")))
                        wrap_lo, wrap_hi = sorted((get("red wrap low"), get("red wrap high")))
                        blue_lo, blue_hi = sorted((get("blue H low"), get("blue H high")))
                        detector.config = replace(config, red_ranges=(((red_lo, sat, val), (red_hi, 255, 255)),
                                                                     ((wrap_lo, sat, val), (wrap_hi, 255, 255))),
                                                  blue_ranges=(((blue_lo, sat, val), (blue_hi, 255, 255)),),
                                                  min_area_px=max(1, get("area min")))
                    targets = detector.detect(packet, calibration)
                    image = packet.image.copy()
                    for target in targets:
                        x, y, w, h = target.bbox_xywh_px
                        color = (0, 255, 0) if target.valid else (0, 180, 255)
                        cv2.rectangle(image, (x, y), (x + w, y + h), color, 2)
                        text = f"{target.object_label} uv={target.center_uv_px} table={target.table_xy_mm} {target.rejected_reason or 'VALID TABLE ONLY'}"
                        cv2.putText(image, text, (x, max(45, y - 8)), cv2.FONT_HERSHEY_SIMPLEX, 0.4, color, 1)
                    cv2.putText(image, f"{mode} {packet.frame_wh_px} frame={packet.frame_id}",
                                (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
                    if not args.headless:
                        cv2.imshow("VisionGrasp camera", image)
                    identity = (packet.camera_session, packet.frame_id)
                    if identity != last_identity:
                        log.write(json.dumps({"event": "frame", "source": packet.source.value,
                                              "session": packet.camera_session, "frame_id": packet.frame_id,
                                              "capture_monotonic_s": packet.capture_monotonic_s,
                                              "actual_wh_px": packet.frame_wh_px,
                                              "targets": [{"label": t.object_label, "valid": t.valid,
                                                           "reason": t.rejected_reason, "uv_px": t.center_uv_px,
                                                           "table_xy_mm": t.table_xy_mm} for t in targets]}) + "\n")
                        last_identity = identity
                if now - last_print >= 1.0:
                    print(json.dumps(health), flush=True)
                    log.write(json.dumps({"event": "health", "elapsed_s": now - started, **health}) + "\n")
                    log.flush()
                    last_print = now
                if not args.headless and cv2.waitKey(1) & 0xFF in (27, ord("q")):
                    break
                time.sleep(0.01)
    finally:
        provider.close()
        if not args.headless:
            cv2.destroyAllWindows()
    print(f"diagnostic log: {path.resolve()}")
    return 0 if saw_frame else 2


if __name__ == "__main__":
    raise SystemExit(main())
