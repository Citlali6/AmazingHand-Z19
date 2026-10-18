"""NCNN 检测后端 —— 板端保底推理（A53 CPU），底层 ncnn API + YOLOv8 头后处理。

模型：``tools/export_yolo_ncnn.py`` 导出（yolov8n @416，COCO 预训练），
IO 张量名 in0/out0，输出 [1, 84, N]（4 box(xywh) + 80 cls，未 NMS）。

预处理（与 ultralytics 对齐，已用 bus.jpg 比对验证）：
letterbox→416 → BGR→RGB → /255 → float32 CHW。

PC 上同一份代码可跑（ncnn pip 跨平台），冒烟测试
``host/tests/smoke_test_vision.py`` 直接覆盖本模块。
"""

from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np

from app.vision.detector import BaseDetector

INPUT_NAME = "in0"
OUTPUT_NAME = "out0"
N_CLASSES = 80


def letterbox(
    frame_bgr: np.ndarray, size: int
) -> tuple[np.ndarray, float, tuple[float, float]]:
    """ultralytics 风格等比缩放填充。返回 (padded RGB, scale, (pad_x, pad_y))。"""
    h, w = frame_bgr.shape[:2]
    scale = min(size / h, size / w)
    nh, nw = round(h * scale), round(w * scale)
    resized = cv2.resize(frame_bgr, (nw, nh), interpolation=cv2.INTER_LINEAR)
    pad_x, pad_y = (size - nw) / 2, (size - nh) / 2
    top, bottom = int(round(pad_y - 0.1)), int(round(pad_y + 0.1))
    left, right = int(round(pad_x - 0.1)), int(round(pad_x + 0.1))
    padded = cv2.copyMakeBorder(resized, top, bottom, left, right,
                                cv2.BORDER_CONSTANT, value=(114, 114, 114))
    rgb = cv2.cvtColor(padded, cv2.COLOR_BGR2RGB)
    return rgb, scale, (left, top)


class NcnnDetector(BaseDetector):
    name = "ncnn"

    def __init__(self, model_dir: str | Path, input_size: int = 416,
                 conf: float = 0.35, iou: float = 0.45,
                 num_threads: int = 4):
        super().__init__(conf, iou)
        import ncnn  # 板端与 PC 同装 ncnn wheel

        model_dir = Path(model_dir)
        self._net = ncnn.Net()
        self._net.opt.num_threads = num_threads
        self._net.opt.use_vulkan_compute = False  # Z19 无 GPU，A53 多线程
        param = model_dir / "model.ncnn.param"
        binw = model_dir / "model.ncnn.bin"
        if not param.exists() or not binw.exists():
            raise FileNotFoundError(f"ncnn model not found in {model_dir}（先跑 tools/export_yolo_ncnn.py）")
        if self._net.load_param(str(param)) != 0 or self._net.load_model(str(binw)) != 0:
            raise RuntimeError('NCNN model load failed')
        self.input_size = input_size

    def detect_raw(self, frame_bgr: np.ndarray) -> list[tuple[int, float, tuple[float, float, float, float]]]:
        rgb, scale, (pad_x, pad_y) = letterbox(frame_bgr, self.input_size)
        # /255 + CHW + **ascontiguousarray（关键）**：transpose 产生非连续内存，
        # ncnn.Mat 按连续布局读取会拿到错位数据（首跑踩坑，见 2026-10-06 log）
        blob = np.ascontiguousarray((rgb.astype(np.float32) / 255.0).transpose(2, 0, 1))

        import ncnn

        with self._net.create_extractor() as ex:
            if ex.input(INPUT_NAME, ncnn.Mat(blob)) != 0:
                raise RuntimeError('NCNN input failed')
            ret, out = ex.extract(OUTPUT_NAME)
        if ret != 0:
            raise RuntimeError(f"ncnn extract failed: {ret}")
        return decode_yolov8(np.array(out), frame_bgr.shape, scale,
                             (pad_x, pad_y), self.conf, self.iou)

    def close(self) -> None:
        self._net.clear()


def decode_yolov8(preds, image_shape, scale, pad, conf=.35, iou=.45):
    """Decoded YOLOv8 head only, [84,N] or [N,84]; class-aware NMS."""
    preds = np.asarray(preds).squeeze()
    if preds.ndim != 2:
        raise ValueError('YOLOv8 output must have two dimensions')
    if preds.shape[0] == 84:
        preds = preds.T
    elif preds.shape[1] != 84:
        raise ValueError('expected decoded 4+80 class head, got %s' % (preds.shape,))
    if not np.isfinite(preds).all():
        raise ValueError('nonfinite YOLOv8 output')
    ids = preds[:, 4:].argmax(axis=1)
    scores = preds[np.arange(len(preds)), ids + 4]
    selected = scores >= conf
    values, ids, scores = preds[selected, :4], ids[selected], scores[selected]
    boxes = np.empty_like(values)
    boxes[:, :2] = values[:, :2] - values[:, 2:] / 2
    boxes[:, 2:] = values[:, :2] + values[:, 2:] / 2
    boxes = (boxes - np.array([pad[0], pad[1], pad[0], pad[1]])) / scale
    boxes[:, [0, 2]] = boxes[:, [0, 2]].clip(0, image_shape[1])
    boxes[:, [1, 3]] = boxes[:, [1, 3]].clip(0, image_shape[0])
    valid = np.all(boxes[:, 2:] > boxes[:, :2], axis=1)
    boxes, ids, scores = boxes[valid], ids[valid], scores[valid]
    remaining = np.argsort(-scores)
    keep = []
    while len(remaining):
        index = remaining[0]
        keep.append(index)
        others = remaining[1:]
        intersection = np.maximum(0, np.minimum(boxes[index, 2:], boxes[others, 2:])
                                  - np.maximum(boxes[index, :2], boxes[others, :2])).prod(axis=1)
        area = np.prod(boxes[:, 2:] - boxes[:, :2], axis=1)
        overlap = intersection / np.maximum(area[index] + area[others] - intersection, 1e-9)
        remaining = others[(ids[others] != ids[index]) | (overlap <= iou)]
    return [(int(ids[k]), float(scores[k]), tuple(float(x) for x in boxes[k])) for k in keep]


def _probe_input_shape(param_path: Path) -> tuple[int, int]:  # pragma: no cover
    """调试辅助：从 param 文本解析输入尺寸（默认 416）。"""
    for line in Path(param_path).read_text(encoding="utf-8").splitlines():
        if line.startswith("InterResize") or "InterResize" in line:
            for tok in line.split():
                if tok.startswith("11="):
                    return int(tok[3:]), int(tok[3:])
    return 416, 416
