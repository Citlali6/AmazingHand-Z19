"""数字孪生实时演示窗口 —— MuJoCo 交互 viewer（给评委/队友/自己看的直观形态）。

动画循环（grasp_table 参数驱动，与实物将执行的同一条姿态序列）::

    张开 → 渐进闭合(banana 抓取姿态) → 保持 → 张开 …循环

操作：鼠标左键旋转 / 滚轮缩放 / 右键平移；关闭窗口即退出。

运行::

    python sim/live_viewer.py          # 需要 OpenGL（Windows 桌面直接可用）
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

import mujoco
import mujoco.viewer  # 显式导入：viewer 为独立子模块（AttributeError 首跑踩坑）
import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "sim"))

from verify_grasp import DEFAULT_MODEL  # noqa: E402

# ---- 演示姿态序列（角度=相对中位，度；与 grasp_table 同源）----
OPEN   = np.array([-35, 35, -35, 35, -35, 35, -35, 35], dtype=float)
GRASP  = np.array([90, -10, 90, -10, 90, -10, 90, -5], dtype=float)
VICTORY = np.array([-65, 15, -65, 15, 90, -90, 90, -90], dtype=float)
THUMB  = np.array([90, -10, 90, -10, 90, -10, 0, -75], dtype=float)

SEQUENCE = [  # (名称, 目标姿态, 时长 s, 是否渐进闭合)
    ("张开",   OPEN,    1.2, True),
    ("预张",   OPEN,    0.4, True),
    ("抓取 banana（渐进力控闭合）", GRASP, 2.0, True),
    ("保持（力控锁存）", GRASP, 1.5, False),
    ("张开",   OPEN,    1.0, True),
    ("胜利手势", VICTORY, 1.5, True),
    ("张开",   OPEN,    0.8, True),
    ("拇指对捏", THUMB, 1.5, True),
    ("张开",   OPEN,    0.8, True),
]

RATE_HZ = 500  # 仿真步频


def main() -> int:
    # 启动日志（诊断窗口不可见问题用）
    log_path = Path(__file__).with_name("viewer_log.txt")
    log_f = open(log_path, "w", encoding="utf-8")

    def log(msg: str) -> None:
        print(msg, flush=True)
        log_f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
        log_f.flush()

    log(f"model: {DEFAULT_MODEL}")
    model = mujoco.MjModel.from_xml_path(str(DEFAULT_MODEL))
    data = mujoco.MjData(model)
    # 复位到中位
    data.ctrl[:] = 0.0
    for _ in range(500):
        mujoco.mj_step(model, data)

    log("viewer launching (a window should appear)...")
    print("MuJoCo 数字孪生实时演示")
    print("操作：左键旋转 / 滚轮缩放 / 右键平移；关闭窗口退出")
    try:
        with mujoco.viewer.launch_passive(model, data) as viewer:
            log("viewer window CREATED OK")
            current = OPEN.copy()
            seg_idx = 0
            seg_t = 0.0
            last = time.perf_counter()
            while viewer.is_running():
                now = time.perf_counter()
                dt = min(now - last, 0.05)
                last = now

                name, target, dur, smooth = SEQUENCE[seg_idx]
                seg_t += dt
                if seg_t >= dur:
                    seg_idx = (seg_idx + 1) % len(SEQUENCE)
                    seg_t = 0.0
                    name, target, dur, smooth = SEQUENCE[seg_idx]
                    print(f"  → {name}")

                # 渐进闭合：模拟 servo_bus_ctrl 每时隙限速逼近（视觉上即力控闭合过程）
                if smooth:
                    k = min(1.0, dt * 2.5)  # 逼近速率
                    current = current + (target - current) * k
                else:
                    current = target.copy()
                data.ctrl[:] = np.radians(current)

                mujoco.mj_step(model, data)
                viewer.sync()
                # 500Hz 全速跑会占满 CPU，锁 ~250Hz
                time.sleep(max(0.0, 1.0 / RATE_HZ - (time.perf_counter() - now)))
            log("viewer closed by user")
    except Exception as exc:  # noqa: BLE001 —— 全量捕获写日志
        import traceback

        log(f"VIEWER FAILED: {type(exc).__name__}: {exc}")
        log(traceback.format_exc())
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
