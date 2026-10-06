"""数字孪生演示窗口（干净版）—— 面向人的展示形态，无任何调试面板。

与 MuJoCo 原生 viewer（工程师调试器）的区别：
- 自绘窗口（OpenCV）：画面只有手 + 中文大字标注（当前动作 / 关节角度）
- 红色 mocap 球（上游 IK 调试用）自动隐藏
- 交互：左键拖拽旋转 / 滚轮缩放 / 空格暂停 / Q 或 ESC 退出

运行::

    python sim/showcase.py
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

import cv2
import mujoco
import numpy as np
from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "sim"))

from verify_grasp import DEFAULT_MODEL  # noqa: E402

W, H = 1280, 800
FONT_PATH = "C:/Windows/Fonts/msyh.ttc"  # 微软雅黑（Windows 自带）

# ---- 演示序列（与 grasp_table 同源）----
OPEN    = np.array([-35, 35, -35, 35, -35, 35, -35, 35], dtype=float)
GRASP   = np.array([90, -10, 90, -10, 90, -10, 90, -5], dtype=float)
VICTORY = np.array([-65, 15, -65, 15, 90, -90, 90, -90], dtype=float)
THUMB   = np.array([90, -10, 90, -10, 90, -10, 0, -75], dtype=float)
POINT   = np.array([-40, 40, 90, -90, 90, -90, 90, -90], dtype=float)

SEQUENCE = [
    ("张开手掌",               OPEN,    1.2, True),
    ("预张（准备抓取）",       OPEN,    0.4, True),
    ("抓取：渐进力控闭合",     GRASP,   2.2, True),
    ("保持：力控锁存",         GRASP,   1.6, False),
    ("张开手掌",               OPEN,    1.0, True),
    ("胜利手势",               VICTORY, 1.6, True),
    ("张开手掌",               OPEN,    0.8, True),
    ("拇指对捏",               THUMB,   1.6, True),
    ("张开手掌",               OPEN,    0.8, True),
    ("食指指向",               POINT,   1.6, True),
    ("张开手掌",               OPEN,    0.8, True),
]


def hide_mocap_spheres(model: mujoco.MjModel) -> int:
    """隐藏上游 XML 的 mocap 调试球（红色），返回隐藏数量。"""
    n = 0
    for g in range(model.ngeom):
        bid = model.geom_bodyid[g]
        if bid >= 0 and model.body_mocapid[bid] >= 0:
            model.geom_rgba[g][3] = 0.0
            n += 1
    return n


def draw_label(frame_bgr: np.ndarray, title: str, sub: str, angles, paused: bool) -> np.ndarray:
    """中文标注：顶部动作名 + 底部关节角条。"""
    img = Image.fromarray(cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(img, "RGBA")
    f_big = ImageFont.truetype(FONT_PATH, 44)
    f_mid = ImageFont.truetype(FONT_PATH, 24)
    f_sm = ImageFont.truetype(FONT_PATH, 20)

    # 顶部动作名（半透明底条）
    draw.rectangle([0, 0, W, 96], fill=(15, 22, 40, 200))
    draw.text((28, 14), title, font=f_big, fill=(255, 255, 255, 255))
    if paused:
        draw.text((W - 150, 26), "已暂停", font=f_mid, fill=(255, 210, 80, 255))

    # 底部关节角（4 指两条：屈曲/外展）
    draw.rectangle([0, H - 76, W, H], fill=(15, 22, 40, 200))
    flex = " ".join(f"{angles[i * 2]:+5.0f}" for i in range(4))
    abd = " ".join(f"{angles[i * 2 + 1]:+5.0f}" for i in range(4))
    draw.text((28, H - 68), f"屈曲 {flex}  (度)", font=f_sm, fill=(180, 220, 255, 255))
    draw.text((28, H - 38), f"外展 {abd}  (度)", font=f_sm, fill=(180, 220, 255, 255))
    draw.text((W - 330, H - 52), "左键旋转 · 滚轮缩放 · Q 退出",
              font=f_sm, fill=(160, 170, 190, 255))
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)


def main() -> int:
    model = mujoco.MjModel.from_xml_path(str(DEFAULT_MODEL))
    hidden = hide_mocap_spheres(model)
    data = mujoco.MjData(model)

    # 帧缓冲尺寸必须在 Renderer 创建前设置（运行时改 mjModel，不动上游 XML）
    model.vis.global_.offwidth = W
    model.vis.global_.offheight = H
    renderer = mujoco.Renderer(model, height=H, width=W)

    # 相机（可交互）
    cam = mujoco.MjvCamera()
    cam.azimuth, cam.elevation, cam.distance = 130, -18, 0.9
    cam.lookat[:] = (0.02, 0.0, 0.14)

    state = {"drag": False, "lx": 0, "ly": 0, "paused": False}

    def on_mouse(event, x, y, flags, _param):
        if event == cv2.EVENT_LBUTTONDOWN:
            state["drag"], state["lx"], state["ly"] = True, x, y
        elif event == cv2.EVENT_LBUTTONUP:
            state["drag"] = False
        elif event == cv2.EVENT_MOUSEMOVE and state["drag"]:
            cam.azimuth = (cam.azimuth - (x - state["lx"]) * 0.4) % 360
            cam.elevation = max(-90, min(90, cam.elevation + (y - state["ly"]) * 0.3))
            state["lx"], state["ly"] = x, y
        elif event == cv2.EVENT_MOUSEWHEEL:
            cam.distance = max(0.25, min(2.5, cam.distance * (1.1 if flags < 0 else 0.9)))

    cv2.namedWindow("AmazingHand 数字孪生演示", cv2.WINDOW_AUTOSIZE)
    cv2.setMouseCallback("AmazingHand 数字孪生演示", on_mouse)

    current = OPEN.copy()
    seg_idx, seg_t = 0, 0.0
    last = time.perf_counter()
    print("演示运行中：Q/ESC 退出，空格暂停")
    while True:
        now = time.perf_counter()
        dt = min(now - last, 0.05)
        last = now

        if not state["paused"]:
            title, target, dur, smooth = SEQUENCE[seg_idx]
            seg_t += dt
            if seg_t >= dur:
                seg_idx = (seg_idx + 1) % len(SEQUENCE)
                seg_t = 0.0
                title, target, dur, smooth = SEQUENCE[seg_idx]
            if smooth:
                current = current + (target - current) * min(1.0, dt * 2.5)
            else:
                current = target.copy()
            data.ctrl[:] = np.radians(current)
            mujoco.mj_step(model, data)

        mujoco.mj_forward(model, data)
        renderer.update_scene(data, camera=cam)
        frame = renderer.render()

        title, target, dur, _ = SEQUENCE[seg_idx]
        progress = min(1.0, seg_t / dur)
        sub = f"阶段 {seg_idx + 1}/{len(SEQUENCE)}  {'█' * int(progress * 20)}{'░' * (20 - int(progress * 20))}"
        disp = draw_label(frame, title, sub, current, state["paused"])
        cv2.imshow("AmazingHand 数字孪生演示", disp)

        key = cv2.waitKey(1) & 0xFF
        if key in (ord("q"), ord("Q"), 27):
            break
        if key == ord(" "):
            state["paused"] = not state["paused"]

    renderer.close()
    cv2.destroyAllWindows()
    print("演示结束")
    return 0


if __name__ == "__main__":
    sys.exit(main())
