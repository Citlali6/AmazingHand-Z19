"""手动调参控制台（单窗口版）—— 8 自由度滑块 + 3D 视图一体。

物理规律保证：
- 限位 = 模型执行器 ctrlrange（MuJoCo 强制）；限速 = 舵机速率逼近（F 切换）；
- 并联机构耦合/连杆干涉/自碰由物理引擎实时解算——只可能出现物理可达的姿态。

参数导出：C=复制 grasp_table JSON 片段到剪贴板；S=保存 manual_poses.json；
1-5=预设姿态。Q/ESC 退出。
"""

from __future__ import annotations

import json
import math
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import cv2
import mujoco
import numpy as np
from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "sim"))

from verify_grasp import DEFAULT_MODEL  # noqa: E402

W, H = 1280, 960          # 上 640 3D + 下 320 控制区
VIEW_H = 640
FONT_PATH = "C:/Windows/Fonts/msyh.ttc"
OUT_JSON = REPO_ROOT / "data/calibration/manual_poses.json"

N = 8
ZH_NAMES = ["食指 屈曲", "食指 外展", "中指 屈曲", "中指 外展",
            "无名指 屈曲", "无名指 外展", "拇指 屈曲", "拇指 外展"]

PRESETS = {
    "1": ("张开",      [-35, 35, -35, 35, -35, 35, -35, 35]),
    "2": ("半握",      [30, 0, 30, 0, 30, 0, 30, 0]),
    "3": ("抓取banana", [90, -10, 90, -10, 90, -10, 90, -5]),
    "4": ("抓apple",   [80, 5, 80, 5, 80, 5, 85, 10]),
    "5": ("拇指对捏",  [90, -10, 90, -10, 90, -10, 0, -75]),
}

# 滑块几何（控制区布局：2 列 × 4 行）
SL_X0, SL_X1 = 250, 600          # 列 1 滑槽
SL2_X0, SL2_X1 = 770, 1120       # 列 2 滑槽
SL_Y0, SL_DY = 730, 62           # 起始行 y / 行距
SL_PICK = 26                     # 命中半径

TITLE = "AmazingHand Manual Control"


def slider_geom(i: int) -> tuple[int, int, int, int]:
    """第 i 个滑块：返回 (x0, x1, y)。"""
    col, row = i % 2, i // 2
    x0 = SL_X0 if col == 0 else SL2_X0
    x1 = SL_X1 if col == 0 else SL2_X1
    return x0, x1, SL_Y0 + row * SL_DY


def main() -> int:
    model = mujoco.MjModel.from_xml_path(str(DEFAULT_MODEL))
    for g in range(model.ngeom):
        bid = model.geom_bodyid[g]
        if bid >= 0 and model.body_mocapid[bid] >= 0:
            model.geom_rgba[g][3] = 0.0
    data = mujoco.MjData(model)

    model.vis.global_.offwidth = 1280
    model.vis.global_.offheight = 640
    renderer = mujoco.Renderer(model, height=640, width=1280)

    # 执行器限位（度）
    lo_deg = np.array([math.degrees(model.actuator_ctrlrange[i][0]) for i in range(N)])
    hi_deg = np.array([math.degrees(model.actuator_ctrlrange[i][1]) for i in range(N)])
    print("执行器限位（度）：")
    for i in range(N):
        print(f"  {ZH_NAMES[i]}: [{lo_deg[i]:+.1f}, {hi_deg[i]:+.1f}]")

    # 滑块当前值（初始化为中位附近：0）
    slider = np.zeros(N)
    target = np.zeros(N)

    cam = mujoco.MjvCamera()
    cam.azimuth, cam.elevation, cam.distance = 130, -18, 0.9
    cam.lookat[:] = (0.02, 0.0, 0.14)
    st = {"drag3d": False, "lx": 0, "ly": 0, "slider": -1}

    def on_mouse(event, x, y, flags, _p):
        if event == cv2.EVENT_LBUTTONDOWN:
            if y >= VIEW_H:  # 控制区：命中滑块
                for i in range(N):
                    x0, x1, sy = slider_geom(i)
                    if abs(y - sy) <= SL_PICK and x0 - 14 <= x <= x1 + 14:
                        st["slider"] = i
                        frac = min(1.0, max(0.0, (x - x0) / (x1 - x0)))
                        target[i] = lo_deg[i] + frac * (hi_deg[i] - lo_deg[i])
                        return
            else:
                st["drag3d"], st["lx"], st["ly"] = True, x, y
        elif event == cv2.EVENT_LBUTTONUP:
            st["drag3d"] = False
            st["slider"] = -1
        elif event == cv2.EVENT_MOUSEMOVE:
            if st["slider"] >= 0:
                i = st["slider"]
                x0, x1, _ = slider_geom(i)
                frac = min(1.0, max(0.0, (x - x0) / (x1 - x0)))
                target[i] = lo_deg[i] + frac * (hi_deg[i] - lo_deg[i])
            elif st["drag3d"]:
                cam.azimuth = (cam.azimuth - (x - st["lx"]) * 0.4) % 360
                cam.elevation = max(-90, min(90, cam.elevation + (y - st["ly"]) * 0.3))
                st["lx"], st["ly"] = x, y
        elif event == cv2.EVENT_MOUSEWHEEL:
            cam.distance = max(0.25, min(2.5, cam.distance * (1.1 if flags < 0 else 0.9)))

    cv2.namedWindow(TITLE, cv2.WINDOW_NORMAL)   # 允许自由缩放窗口
    cv2.resizeWindow(TITLE, W, H)
    try:  # 保持 4:3 纵横比（版本不支持则忽略）
        cv2.setWindowProperty(TITLE, cv2.WND_PROP_ASPECT_RATIO, W / H)
    except Exception:  # noqa: BLE001
        pass
    cv2.setMouseCallback(TITLE, on_mouse)

    f_big = ImageFont.truetype(FONT_PATH, 34)
    f_mid = ImageFont.truetype(FONT_PATH, 21)
    f_sm = ImageFont.truetype(FONT_PATH, 18)

    current = np.zeros(N)
    speed_dps = 40.0
    last = time.perf_counter()
    print("滑块拖动控制 | C 复制JSON | S 保存 | 1-5 预设 | F 切限速 | Q/ESC 退出")

    while True:
        now = time.perf_counter()
        dt = min(now - last, 0.05)
        last = now

        # 限速逼近（物理：舵机不可能瞬移）
        delta = np.clip(target - current, -speed_dps * dt, speed_dps * dt)
        current += delta
        data.ctrl[:] = np.radians(current)
        for _ in range(8):
            mujoco.mj_step(model, data)

        mujoco.mj_forward(model, data)
        renderer.update_scene(data, camera=cam)
        frame = renderer.render()

        # ---- 组合画面：先建 960 高画布，再贴 3D 帧(640) + 控制面板(320) ----
        img = Image.new("RGBA", (W, H), (16, 22, 36, 255))
        img.paste(Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)), (0, 0))
        draw = ImageDraw.Draw(img, "RGBA")

        draw.text((20, VIEW_H + 8), "8 自由度控制 — 拖动滑块（限位/限速由物理保证）",
                  font=f_mid, fill=(235, 240, 250))
        draw.text((20, VIEW_H + 36),
                  "注意：运动学模型（上游 CAD 无碰撞几何，指间可交叉）· 碰撞简化体建模已列入待办",
                  font=f_sm, fill=(255, 170, 120))
        for i in range(N):
            x0, x1, y = slider_geom(i)
            lo, hi = lo_deg[i], hi_deg[i]
            # 名称 + 数值
            moving = abs(target[i] - current[i]) > 0.5
            color = (255, 200, 90) if moving else (120, 220, 140)
            draw.text((28 if i % 2 == 0 else 540, y - 26),
                      f"{ZH_NAMES[i]}", font=f_mid, fill=(220, 228, 245))
            draw.text((x1 + 12, y - 12), f"{current[i]:+6.1f}°",
                      font=f_mid, fill=color)
            # 滑槽
            draw.rounded_rectangle([x0, y - 4, x1, y + 4], radius=4,
                                   fill=(45, 55, 78))
            # 限位刻度
            draw.text((x0 - 10, y + 10), f"{lo:+.0f}", font=f_sm, fill=(120, 130, 150))
            draw.text((x1 - 24, y + 10), f"{hi:+.0f}", font=f_sm, fill=(120, 130, 150))
            # 滑块圆点（当前实际值位置）
            frac = (current[i] - lo) / max(1e-6, hi - lo)
            cx = x0 + frac * (x1 - x0)
            tf = (target[i] - lo) / max(1e-6, hi - lo)
            tx = x0 + tf * (x1 - x0)
            draw.ellipse([tx - 5, y - 5, tx + 5, y + 5], fill=(90, 110, 150))   # 目标
            draw.ellipse([cx - 9, y - 9, cx + 9, y + 9], fill=color)            # 实际

        draw.text((24, H - 34),
                  f"限速 {speed_dps:.0f}°/s [F] · [C]复制JSON [S]保存 [1-5]预设 [Q]退出"
                  f"   目标圈(灰)→实际圆(黄/绿)",
                  font=f_sm, fill=(150, 165, 190))

        disp = cv2.cvtColor(np.array(img.convert("RGB")), cv2.COLOR_RGB2BGR)
        # 窗口自适应：按客户区尺寸缩放输出（窗口可自由拖大/最大化）
        rect = cv2.getWindowImageRect(TITLE)
        if rect is not None and rect[2] > 0 and (rect[2], rect[3]) != (W, H):
            disp = cv2.resize(disp, (rect[2], rect[3]))
        cv2.imshow(TITLE, disp)

        key = cv2.waitKey(1) & 0xFF
        if key in (ord("q"), ord("Q"), 27):
            break
        elif key == ord("f") or key == ord("F"):
            speed_dps = 180.0 if speed_dps == 40.0 else 40.0
            print(f"限速 → {speed_dps:.0f}°/s")
        elif key == ord("c") or key == ord("C"):
            entry = json.dumps({"angles_deg": [round(v, 1) for v in current]},
                               ensure_ascii=False)
            subprocess.run("clip", input=entry.encode("utf-16le"), check=False)
            print(f"已复制: {entry}")
        elif key == ord("s") or key == ord("S"):
            OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
            book = (json.loads(OUT_JSON.read_text(encoding="utf-8"))
                    if OUT_JSON.exists() else {"poses": {}})
            name = f"manual_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            book["poses"][name] = {"angles_deg": [round(v, 1) for v in current],
                                   "source": "manual", "note": "control_panel"}
            OUT_JSON.write_text(json.dumps(book, ensure_ascii=False, indent=2),
                                encoding="utf-8")
            print(f"已保存 → {OUT_JSON} [{name}]")
        elif 32 <= key < 127 and chr(key) in PRESETS:
            pname, pangles = PRESETS[chr(key)]
            target[:] = np.array(pangles)
            print(f"预设: {pname}")

    renderer.close()
    cv2.destroyAllWindows()
    print("控制台退出")
    return 0


if __name__ == "__main__":
    sys.exit(main())
