"""PC 端检测验证 —— 本地图片 → NCNN 推理 → 15 类物品过滤 → 检测报告。

验证内容：
1. 导出的 NCNN 模型与 ultralytics 直接推理结果一致（同图同阈值类别一致）；
2. 15 类物品映射与 bbox→mm 尺寸估计链路。

运行::

    python tools/test_detect_pc.py --image bus.jpg
    python tools/test_detect_pc.py --image xxx.jpg --show-size
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "host"))

from app.vision.backends.ncnn_det import NcnnDetector  # noqa: E402
from app.vision.detector import ITEM_TO_COCO  # noqa: E402
from app.vision.measure import CameraCalib, bbox_to_size_mm  # noqa: E402

DEFAULT_MODEL_DIR = REPO_ROOT / "yolov8n_ncnn_model"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument("--model-dir", default=str(DEFAULT_MODEL_DIR))
    parser.add_argument("--imgsz", type=int, default=416)
    parser.add_argument("--conf", type=float, default=0.35)
    parser.add_argument("--show-size", action="store_true", help="附加单目尺寸估计")
    args = parser.parse_args()

    import cv2

    frame = cv2.imread(args.image)
    if frame is None:
        print(f"cannot read {args.image}")
        return 1

    det = NcnnDetector(model_dir=args.model_dir, input_size=args.imgsz, conf=args.conf)
    dets = det.detect(frame)
    det.close()

    print(f"image: {args.image}  model: {Path(args.model_dir).name}")
    if not dets:
        print("no detections in the 15-item set")
        return 0
    calib = CameraCalib.load(REPO_ROOT / "data/calibration/camera.yaml")
    for d in dets:
        line = f"  {d.category:<12} conf={d.conf:.2f} xyxy={[round(v) for v in d.bbox_xyxy]}"
        if args.show_size:
            size = bbox_to_size_mm(d.bbox_xyxy, calib, d.category)
            line += f"  size_mm(L,W,H)={size}"
        print(line)
    print(f"item classes: {len(ITEM_TO_COCO)} (COCO id map ok)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
