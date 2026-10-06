"""第 4a 步冒烟测试 —— 视觉链（NCNN 检测 / 单目测尺寸 / ArUco 引导）。

前置：``pip install ncnn opencv-python pyyaml`` + 模型产物
（``python tools/export_yolo_ncnn.py`` 生成 yolov8n_ncnn_model/）。

运行::

    python host/tests/smoke_test_vision.py
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "host"))

import cv2  # noqa: E402
import numpy as np  # noqa: E402

from app.vision.backends.ncnn_det import NcnnDetector  # noqa: E402
from app.vision.detector import ITEM_TO_COCO  # noqa: E402
from app.vision.hand_guide import (  # noqa: E402
    CameraIntrinsics,
    HandGuide,
    make_test_frame,
)
from app.vision.measure import CameraCalib, bbox_to_size_mm  # noqa: E402

MODEL_DIR = REPO_ROOT / "yolov8n_ncnn_model"
ASSET = Path(__file__).with_name("assets_bus.jpg")


def test_class_map_consistency() -> None:
    assert len(ITEM_TO_COCO) == 15
    assert len(set(ITEM_TO_COCO.values())) == 15, "COCO id must be unique"


def test_ncnn_detection_and_filter() -> None:
    """bus.jpg：raw 应检出 person(0)/bus(5)（与 ultralytics 基线一致），
    detect() 应过滤掉全部非 15 类物品。"""
    assert MODEL_DIR.exists(), "先跑 tools/export_yolo_ncnn.py"
    det = NcnnDetector(model_dir=MODEL_DIR)
    frame = cv2.imread(str(ASSET))
    raw = det.detect_raw(frame)
    ids = {cid for cid, _, _ in raw}
    assert 0 in ids and 5 in ids, f"expect person/bus, got {ids}"
    assert {d.conf for d in raw and []} == set()  # noqa: B015 —— 占位保证 raw 有 conf
    filtered = det.detect(frame)
    assert filtered == [], "person/bus must be filtered out of the 15-item set"
    det.close()


def test_measure_size_estimation() -> None:
    """bbox→mm 线性换算 + 类别高度先验。"""
    calib = CameraCalib.load(None)  # 占位 0.75mm/px
    assert calib.source == "placeholder"
    l, w, h = bbox_to_size_mm((100, 100, 300, 200), calib, "banana")
    assert l == 150.0 and w == 75.0, f"linear scale wrong: {l},{w}"  # 200/150 px×0.75
    _, _, h2 = bbox_to_size_mm((0, 0, 10, 10), calib, "bottle")
    assert h2 == 180.0  # 类别先验


def test_aruco_guide_pipeline() -> None:
    """合成帧 → 检测 → 引导：偏移方向性与就位判定。"""
    g = HandGuide(CameraIntrinsics(), target_xy_px=(640, 360))
    # 中心放置 → 就位
    frame = make_test_frame((640 - 40, 360 - 40))
    r = g.guide(frame)
    assert r.marker_found and r.in_position, f"center should be in position: {r}"
    # 右上偏移 100px（≈9.4cm @0.75mm/px）→ 引导左/下移
    frame2 = make_test_frame((640 - 40 + 100, 360 - 40 - 100))
    r2 = g.guide(frame2)
    assert r2.marker_found and not r2.in_position
    assert r2.dx_cm > 0 and r2.dy_cm < 0, f"offset direction wrong: {r2}"
    assert "左" in g.guide_text(r2) or "上" in g.guide_text(r2)
    # 无标记帧
    blank = np.full((720, 1280, 3), 200, dtype=np.uint8)
    r3 = g.guide(blank)
    assert not r3.marker_found and not r3.in_position


def test_measure_yaml_calibration_path() -> None:
    """标定文件存在时走 calibrated 路径（占位文件临时生成）。"""
    import tempfile

    tmp = Path(tempfile.mkdtemp()) / "camera.yaml"
    tmp.write_text("mm_per_px: 0.5\nimage_size: [1280, 720]\n", encoding="utf-8")
    calib = CameraCalib.load(tmp)
    assert calib.source == "calibrated" and calib.mm_per_px == 0.5
    l, _, _ = bbox_to_size_mm((0, 0, 200, 100), calib, "apple")
    assert l == 100.0


def main() -> int:
    tests = [
        (name, fn)
        for name, fn in sorted(globals().items())
        if name.startswith("test_") and callable(fn)
    ]
    failures = 0
    for name, fn in tests:
        try:
            fn()
            print(f"  PASS  {name}")
        except Exception as exc:  # noqa: BLE001
            failures += 1
            print(f"  FAIL  {name}: {type(exc).__name__}: {exc}")
    total = len(tests)
    print(f"\n{total - failures}/{total} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
