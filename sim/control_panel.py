"""手动调参控制台（单窗口）—— 8 自由度滑块 + 3D 视图 + 机构可行性监测。

物理规律保证：
- 关节限位 = 模型执行器 ctrlrange（MuJoCo 强制）；
- 舵机限速逼近（F 切换 40/180°/s）；
- **机构可行性监测**：并联机构由 equality 约束维持，滑块目标超出机构
  可行域时约束残差上升——右上角"机构应力"条实时显示，红色 = 当前
  姿态在真实手上不可达/连杆过度受力（本模型上游无碰撞几何，几何交叉
  用应力灯提示）。

交互（窗口可任意缩放，坐标自动换算）：
  左键拖拽 3D 区=旋转视角 / 滑块区=调参数；滚轮=缩放；
  C=复制JSON  S=保存manual_poses  1-5=预设  F=切限速  Q/ESC=退出（点 X 同效）。
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

W, H = 1280, 960
VIEW_H = 560
FONT_PATH = "C:/Windows/Fonts/msyh.ttc"
OUT_JSON = REPO_ROOT / "data/calibration/manual_poses.json"
TITLE = "AmazingHand Manual Control"

N = 8
ZH_NAMES = ["食指 屈曲", "食指 外展", "中指 屈曲", "中指 外展",
            "无名指 屈曲", "无名指 外展", "拇指 屈曲", "拇指 外展"]

PRESETS = {
    "1": ("张开（模型零位）", [0, 0, 0, 0, 0, 0, 0, 0]),
    "2": ("半握",      [30, 0, 30, 0, 30, 0, 30, 0]),
    "3": ("抓取banana", [90, -10, 90, -10, 90, -10, 90, -5]),
    "4": ("抓apple",   [80, 5, 80, 5, 80, 5, 85, 10]),
    "5": ("拇指对捏",  [90, -10, 90, -10, 90, -10, 0, -75]),
}

# 滑块几何（2 列 × 4 行，严格对齐网格）
COLS = [  # (名称x, 滑槽x0, 滑槽x1, 数值x)
    dict(name=24,  x0=170, x1=500, val=520),
    dict(name=660, x0=806, x1=1136, val=1156),
]
ROW0, ROW_DY = 668, 68


def slider_geom(i: int) -> tuple[dict, int]:
    return COLS[i // 4], ROW0 + (i % 4) * ROW_DY


def main() -> int:
    from collision_model import build_collision_model  # 碰撞简化体（防穿模）

    model = build_collision_model()
    for g in range(model.ngeom):  # 隐藏上游 mocap 调试球
        bid = model.geom_bodyid[g]
        if bid >= 0 and model.body_mocapid[bid] >= 0:
            model.geom_rgba[g][3] = 0.0
    data = mujoco.MjData(model)

    model.vis.global_.offwidth = 1280
    model.vis.global_.offheight = VIEW_H
    renderer = mujoco.Renderer(model, height=VIEW_H, width=1280)

    lo_deg = np.array([math.degrees(model.actuator_ctrlrange[i][0]) for i in range(N)])
    hi_deg = np.array([math.degrees(model.actuator_ctrlrange[i][1]) for i in range(N)])

    cam = mujoco.MjvCamera()
    cam.azimuth, cam.elevation, cam.distance = 130, -18, 0.9
    cam.lookat[:] = (0.02, 0.0, 0.14)
    st = {"drag3d": False, "lx": 0, "ly": 0, "slider": -1}

    def to_img(x: int, y: int) -> tuple[float, float]:
        """窗口坐标 → 1280×960 图像坐标（WINDOW_NORMAL 缩放换算）。"""
        rect = cv2.getWindowImageRect(TITLE)
        if rect is None or rect[2] <= 0:
            return float(x), float(y)
        return x * W / rect[2], y * H / rect[3]

    def on_mouse(event, x, y, flags, _p):
        ix, iy = to_img(x, y)
        if event == cv2.EVENT_LBUTTONDOWN:
            if iy >= VIEW_H:  # 控制区
                # 复位按钮命中
                if BTN_RESET[0] <= ix <= BTN_RESET[2] and BTN_RESET[1] <= iy <= BTN_RESET[3]:
                    st["do_reset"] = True
                    return
                for i in range(N):
                    col, sy = slider_geom(i)
                    if abs(iy - sy) <= 26 and col["x0"] - 16 <= ix <= col["x1"] + 16:
                        st["slider"] = i
                        frac = min(1.0, max(0.0, (ix - col["x0"]) / (col["x1"] - col["x0"])))
                        target[i] = lo_deg[i] + frac * (hi_deg[i] - lo_deg[i])
                        return
            st["drag3d"], st["lx"], st["ly"] = True, ix, iy
        elif event == cv2.EVENT_LBUTTONUP:
            st["drag3d"] = False
            st["slider"] = -1
        elif event == cv2.EVENT_MOUSEMOVE:
            if st["slider"] >= 0:
                i = st["slider"]
                col, _ = slider_geom(i)
                frac = min(1.0, max(0.0, (ix - col["x0"]) / (col["x1"] - col["x0"])))
                target[i] = lo_deg[i] + frac * (hi_deg[i] - lo_deg[i])
            elif st["drag3d"]:
                cam.azimuth = (cam.azimuth - (ix - st["lx"]) * 0.4) % 360
                cam.elevation = max(-90, min(90, cam.elevation + (iy - st["ly"]) * 0.3))
                st["lx"], st["ly"] = ix, iy
        elif event == cv2.EVENT_MOUSEWHEEL:
            cam.distance = max(0.25, min(2.5, cam.distance * (1.1 if flags < 0 else 0.9)))

    cv2.namedWindow(TITLE, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(TITLE, W, H)
    cv2.setMouseCallback(TITLE, on_mouse)

    f_big = ImageFont.truetype(FONT_PATH, 32)
    f_mid = ImageFont.truetype(FONT_PATH, 21)
    f_sm = ImageFont.truetype(FONT_PATH, 18)

    # 初始姿态 = 模型零位（ctrl=0 即自然张开扇形；官方 Demo 的 ±35° 是
    # "舵机校准中位偏移"语义，与模型零位不对齐——映射待定项 1 实机校准）
    current = np.array(PRESETS["1"][1], dtype=float)
    target = current.copy()
    data.ctrl[:] = np.radians(current)
    for _ in range(800):  # 0.8s 预稳定：接触沉降到平衡
        mujoco.mj_step(model, data)
    speed_dps = 40.0
    stress = 0.0  # 机构应力（equality 残差归一）
    warn = {"active": False, "msg": "", "pen": 0.0, "ncon": 0}
    last = time.perf_counter()
    print("滑块控制 | C 复制JSON | S 保存 | 1-5 预设 | F 限速 | R/按钮=复位 | Q/ESC 退出")

    # 复位按钮几何（图像坐标）
    BTN_RESET = (1080, VIEW_H + 8, 1256, VIEW_H + 54)

    def do_reset() -> None:
        """全部复位：目标归零（张开工位），180°/s 快速回归，清除警告。"""
        nonlocal speed_dps
        target[:] = 0.0
        speed_dps = 180.0
        warn["active"] = False
        warn["msg"] = ""
        print("已复位 → 张开工位（180°/s 回归中，F 可切回 40°/s）")

    while True:
        # 点 X 关闭窗口 → 退出（修复：关窗不死进程）
        if cv2.getWindowProperty(TITLE, cv2.WND_PROP_VISIBLE) < 1:
            break

        now = time.perf_counter()
        dt = min(now - last, 0.05)
        last = now

        if st.get("do_reset"):
            st["do_reset"] = False
            do_reset()

        delta = np.clip(target - current, -speed_dps * dt, speed_dps * dt)
        current += delta
        data.ctrl[:] = np.radians(current)
        for _ in range(8):
            mujoco.mj_step(model, data)

        # ---- 穿透/接触监测（警告机制）----
        max_pen, ncon = 0.0, data.ncon
        for c in range(ncon):
            max_pen = max(max_pen, -float(data.contact[c].dist))
        if max_pen > 0.002 or stress > 0.9:  # 穿透 >2mm 或应力拉满
            if not warn["active"]:
                print(f"⚠ 警告：接触穿透 {max_pen * 1000:.1f}mm / 应力 {stress:.0%} —— 请复位")
            warn["active"] = True
            warn["msg"] = f"接触穿透 {max_pen * 1000:.1f}mm · 应力 {stress:.0%} · 请复位"
            warn["pen"] = max_pen
        elif warn["active"] and max_pen < 0.0005:
            warn["active"] = False  # 恢复正常即解除
        warn["ncon"] = ncon

        # 机构应力：equality 约束残差归一（>0.3 警告，>1 严重）
        raw = 0.0
        if data.nefc > 0:
            efc_pos = np.asarray(data.efc_pos)[: data.nefc]
            efc_type = np.asarray(data.efc_type)[: data.nefc]
            eq = efc_pos[efc_type == 0]  # mjCNSTR_EQUALITY
            if eq.size:
                raw = float(np.abs(eq).max())
        stress += (min(1.0, raw / 0.004) - stress) * 0.2

        mujoco.mj_forward(model, data)
        renderer.update_scene(data, camera=cam)
        frame = renderer.render()

        # ---- 组合画面 ----
        img = Image.new("RGBA", (W, H), (16, 22, 36, 255))
        img.paste(Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)), (0, 0))
        draw = ImageDraw.Draw(img, "RGBA")

        # 控制区标题 + 机构应力灯 + 接触信息
        draw.text((24, VIEW_H + 12), "8 自由度控制", font=f_big, fill=(235, 240, 250))
        bar_x, bar_y, bar_w = 320, VIEW_H + 26, 320
        draw.text((bar_x - 6, bar_y - 4), "机构应力", font=f_sm, fill=(170, 185, 210))
        draw.rounded_rectangle([bar_x + 70, bar_y, bar_x + 70 + bar_w, bar_y + 14],
                               radius=6, fill=(40, 50, 72))
        sw = int(bar_w * min(1.0, stress))
        scolor = (120, 220, 140) if stress < 0.3 else (
            (255, 200, 90) if stress < 0.7 else (255, 90, 90))
        if sw > 2:
            draw.rounded_rectangle([bar_x + 70, bar_y, bar_x + 70 + sw, bar_y + 14],
                                   radius=6, fill=scolor)
        state_txt = "机构正常" if stress < 0.3 else (
            "接近连杆极限" if stress < 0.7 else "⚠ 超出机构可行域（真实手无法到达）")
        draw.text((bar_x + 70 + bar_w + 14, bar_y - 3), state_txt,
                  font=f_sm, fill=scolor)
        contact_txt = (f"接触 {warn['ncon']} 对 · 最大穿透 {warn['pen'] * 1000:.1f}mm"
                       if warn["ncon"] else "无接触")
        draw.text((24, VIEW_H + 46), contact_txt, font=f_sm,
                  fill=(255, 170, 120) if warn["pen"] > 2 else (140, 220, 160))
        draw.text((24, VIEW_H + 72),
                  "碰撞体 v2（壳体包围盒胶囊×8）——指间交叉被物理阻挡",
                  font=f_sm, fill=(120, 135, 160))

        # ---- 复位按钮（右上）----
        bx0, by0, bx1, by1 = BTN_RESET
        draw.rounded_rectangle([bx0, by0, bx1, by1], radius=10,
                               fill=(30, 120, 80) if not warn["active"] else (170, 60, 50))
        draw.text((bx0 + 18, by0 + 8), "⟳ 全部复位 (R)", font=f_mid,
                  fill=(255, 255, 255))

        # ---- 警告横幅（3D 顶部，闪烁）----
        if warn["active"]:
            blink = int(time.perf_counter() * 2) % 2 == 0
            alpha = 220 if blink else 150
            draw.rectangle([0, 0, W, 64], fill=(190, 40, 30, alpha))
            draw.text((24, 10), f"⚠ {warn['msg']} —— 点击复位按钮或按 R",
                      font=f_mid, fill=(255, 255, 255))

        # 滑块（对齐网格）
        for i in range(N):
            col, y = slider_geom(i)
            lo, hi = lo_deg[i], hi_deg[i]
            moving = abs(target[i] - current[i]) > 0.5
            dot = (255, 200, 90) if moving else (120, 220, 140)
            draw.text((col["name"], y - 12), ZH_NAMES[i], font=f_mid,
                      fill=(220, 228, 245))
            draw.rounded_rectangle([col["x0"], y - 4, col["x1"], y + 4],
                                   radius=4, fill=(45, 55, 78))
            draw.text((col["x0"], y + 10), f"{lo:+.0f}", font=f_sm,
                      fill=(120, 130, 150))
            draw.text((col["x1"] - 30, y + 10), f"{hi:+.0f}", font=f_sm,
                      fill=(120, 130, 150))
            tf = (target[i] - lo) / max(1e-6, hi - lo)
            tx = col["x0"] + tf * (col["x1"] - col["x0"])
            draw.ellipse([tx - 5, y - 5, tx + 5, y + 5], fill=(90, 110, 150))
            frac = (current[i] - lo) / max(1e-6, hi - lo)
            cx = col["x0"] + frac * (col["x1"] - col["x0"])
            draw.ellipse([cx - 9, y - 9, cx + 9, y + 9], fill=dot)
            draw.text((col["val"], y - 12), f"{current[i]:+6.1f}°",
                      font=f_mid, fill=dot)

        draw.text((24, H - 30),
                  "限速 [F]40/180°/s · [C]复制JSON [S]保存 [1-5]预设 · "
                  "3D区左键旋转 滚轮缩放 · [R]/按钮=复位 · [Q]退出",
                  font=f_sm, fill=(150, 165, 190))

        disp = cv2.cvtColor(np.array(img.convert("RGB")), cv2.COLOR_RGB2BGR)
        rect = cv2.getWindowImageRect(TITLE)
        if rect is not None and rect[2] > 0 and (rect[2], rect[3]) != (W, H):
            disp = cv2.resize(disp, (rect[2], rect[3]))
        cv2.imshow(TITLE, disp)

        key = cv2.waitKey(1) & 0xFF
        if key in (ord("q"), ord("Q"), 27):
            break
        elif key == ord("f") or key == ord("F"):
            speed_dps = 180.0 if speed_dps == 40.0 else 40.0
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
        elif key == ord("r") or key == ord("R"):
            do_reset()
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
