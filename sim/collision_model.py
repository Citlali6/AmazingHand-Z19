"""碰撞简化体注入 —— 为上游无碰撞模型（纯动画/运动学）构建物理版。

背景：上游 AHSimulation 的全部 geom 均为 ``contype=0 conaffinity=0``
（CAD 全量杆系，纯动画导向），手指与手掌可无限穿透。

本模块用 MjSpec 在**运行时**注入简化碰撞体（上游 XML 文件不动）：
- 每指 1 根覆盖全指的 capsule（挂在指根舵机 body 上，跟随手指运动）；
- 手掌 1 个 box；
- 注入 geoms 的 contype/conaffinity=1 → 只与彼此及地板碰撞；
  连杆零件（无碰撞）与指节重叠不受影响，不会引起杆系爆炸。

使用::

    from collision_model import build_collision_model
    model = build_collision_model()          # 替代 MjModel.from_xml_path

标定意义：碰撞体使控制台/仿真拒绝物理不可达的交叉姿态，
导出参数天然满足"实机不干涉"约束。
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import mujoco
import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "sim"))

from verify_grasp import DEFAULT_MODEL  # noqa: E402

#: 手指胶囊（半径 m）——贴合指节壳内侧
FINGER_RADIUS = 0.0085
#: 手掌碰撞盒半尺寸（m）
PALM_HALF = (0.028, 0.020, 0.050)
PALM_CENTER_LOCAL = (0.0, 0.0, 0.055)  # r_wrist_interface 局部系掌心

# 每指：(指根舵机 body 名, tip site 名)
FINGERS = [
    ("custom_servo_horn", "tip1"),
    ("custom_servo_horn_2", "tip2"),
    ("custom_servo_horn_3", "tip3"),
    ("custom_servo_horn_4", "tip4"),
]


def _quat_z_to(vec_local: np.ndarray) -> np.ndarray:
    """生成把 capsule 默认 z 轴对齐到 vec_local 的四元数 (w,x,y,z)。"""
    v = vec_local / (np.linalg.norm(vec_local) + 1e-12)
    z = np.array([0.0, 0.0, 1.0])
    axis = np.cross(z, v)
    s = np.linalg.norm(axis)
    if s < 1e-9:  # 平行
        return np.array([1.0, 0, 0, 0]) if v[2] > 0 else np.array([0.0, 1.0, 0, 0])
    axis /= s
    angle = math.atan2(s, float(np.dot(z, v)))
    return np.concatenate([[np.cos(angle / 2)], np.sin(angle / 2) * axis])


def build_collision_model(verbose: bool = False) -> mujoco.MjModel:
    """加载上游模型并注入碰撞简化体，返回编译后的 MjModel。"""
    spec = mujoco.MjSpec.from_file(str(DEFAULT_MODEL))

    # 先 forward 一次拿世界位姿（用于计算局部几何）
    tmp = spec.compile()
    d = mujoco.MjData(tmp)
    mujoco.mj_forward(tmp, d)

    def bid(name: str) -> int:
        i = mujoco.mj_name2id(tmp, mujoco.mjtObj.mjOBJ_BODY, name)
        assert i >= 0, f"body not found: {name}"
        return i

    added = 0
    for root_name, tip_name in FINGERS:
        rb = bid(root_name)
        # 指根 body 的世界位姿
        R = d.xmat[rb].reshape(3, 3)
        p_root = d.xpos[rb].copy()
        # 指尖位置（世界）→ 指根局部系
        sid = mujoco.mj_name2id(tmp, mujoco.mjtObj.mjOBJ_SITE, tip_name)
        p_tip = d.site_xpos[sid].copy()
        v_local = R.T @ (p_tip - p_root)  # 指根→指尖（局部）
        length = float(np.linalg.norm(v_local))
        half = max(0.005, length / 2 - FINGER_RADIUS * 0.5)
        mid = v_local / 2.0
        quat = _quat_z_to(v_local)

        body = spec.body(root_name)
        body.add_geom(
            type=mujoco.mjtGeom.mjGEOM_CAPSULE,
            size=[FINGER_RADIUS, half, 0.0],
            pos=[float(mid[0]), float(mid[1]), float(mid[2])],
            quat=[float(quat[0]), float(quat[1]), float(quat[2]), float(quat[3])],
            contype=1, conaffinity=1,
            group=3,  # 碰撞层（默认不渲染，可在 viewer 打开）
            rgba=[0.2, 0.5, 1.0, 0.15],
            solref=[0.004, 1],  # 稍软接触，防求解器抖动
        )
        added += 1
        if verbose:
            print(f"  + finger capsule [{root_name}] len={length * 1000:.0f}mm")

    # 手掌碰撞盒（挂在手腕接口 body）
    wb = spec.body("r_wrist_interface")
    wb.add_geom(
        type=mujoco.mjtGeom.mjGEOM_BOX,
        size=list(PALM_HALF),
        pos=list(PALM_CENTER_LOCAL),
        contype=1, conaffinity=1,
        group=3,
        rgba=[0.2, 0.5, 1.0, 0.12],
        solref=[0.004, 1],
    )
    added += 1

    model = spec.compile()
    if verbose:
        print(f"collision geoms injected: {added}（总 geom {model.ngeom}）")
    return model


if __name__ == "__main__":
    m = build_collision_model(verbose=True)
    d = mujoco.MjData(m)
    mujoco.mj_forward(m, d)
    # 稳定性冒烟：抓取姿态 1s，检查不发散
    m.actuator_ctrl[:] = np.radians([90, -10, 90, -10, 90, -10, 90, -5])
    for _ in range(2000):
        mujoco.mj_step(m, d)
    ok = np.all(np.isfinite(d.qpos))
    print(f"stability smoke: qpos finite={ok}, max|qacc|={np.abs(d.qacc).max():.2f}")
    sys.exit(0 if ok else 1)
