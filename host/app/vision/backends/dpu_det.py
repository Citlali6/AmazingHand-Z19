"""DPU 检测后端 —— Vitis AI 加速链路（板端可选，PC 不可用）。

依赖板端 vart 运行时（ALINX 镜像自带，不进 pip）：加载 xmodel 执行 DPU 推理。
PC 上 import 即失败——detector.py 工厂仅在 backend=dpu 时导入本模块。

模型：``fpga/scripts/build_dpu.tcl`` 生成 B4096 DPU overlay 后，
由 ``vai_q`` 量化/编译 YOLOv8n 得到 xmodel（量化校准集 = COCO val 子集）。
当前为接口占位：板端 Vitis AI 链路调通后补齐 preprocess/postprocess
（与 ncnn_det 保持同一 Detection 契约，保证后端可切换）。
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

from app.vision.detector import BaseDetector


class DpuDetector(BaseDetector):
    name = "dpu"

    def __init__(self, xmodel: str | Path, conf: float = 0.35, iou: float = 0.45):
        super().__init__(conf, iou)
        self.xmodel = Path(xmodel)
        try:
            import xir
            import vart  # noqa: F401
        except ImportError as exc:  # pragma: no cover —— PC 上必走此分支
            raise RuntimeError(
                "DpuDetector 需要 Vitis AI 运行时（vart/xir），仅板端可用；"
                "PC 请使用 backend: ncnn"
            ) from exc
        self._graph = xir.Graph(self.xmodel)
        self._runner = vart.Runner.create_runner(self._graph.get_root_subgraph(), "run")

    def detect_raw(self, frame_bgr: np.ndarray) -> list[tuple[int, float, tuple[float, float, float, float]]]:
        # TODO(板端联调)：输入量化预处理（vart.RUNTIME_QA）+ DPU 前向 + YOLOv8 头解码
        # 保持与 NcnnDetector.detect_raw 相同的返回契约
        raise NotImplementedError("DPU 后端待板端 Vitis AI 链路调通后实现（第 5 步联调项）")
