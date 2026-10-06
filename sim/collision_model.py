"""碰撞简化体注入 v2 —— 按壳体 mesh 包围盒自动生成贴合胶囊。

v1 教训：手工"根→tip 直棒"胶囊（r=5mm）无法表达 24mm 宽的指节壳，
横向交叉挡不住；手掌盒与指根胶囊初始嵌接触卡死屈曲关节。

v2 方法（数据驱动，无手工几何）：
- 扫描上游 geom，凡 mesh 名命中壳体表（proximal/distal shell、掌板）→
  在同一 body 上生成**同位姿**的碰撞体：
    · 长轴沿 mesh AABB 最长维（proximal/distal 均为 z）
    · 半径 = 横截面半宽 × 收缩系数（壳体 rounded 外缘）
    · 长度 = AABB 长轴长
- 壳体 geom 之间 contype=1 → 指节-指节 / 指节-掌 板碰撞生效；
  连杆/其它零件仍无碰撞（杆系零干扰）。

使用::

    from collision_model import build_collision_model
    model = build_collision_model()
"""

from __future__ import annotations

import sys
from pathlib import Path

import mujoco
import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "sim"))

from verify_grasp import DEFAULT_MODEL  # noqa: E402

#: 壳体 mesh 名 → 碰撞体配置（radius_scale：横截面半宽 × 系数）
#: r_hand_plate 排除：其 mesh AABB 半宽 46mm 会包住整手（多块板的大包围盒）
SHELL_RULES = {
    "proximal": 0.85,
    "distal": 0.85,
}


def build_collision_model(verbose: bool = False) -> mujoco.MjModel:
    spec = mujoco.MjSpec.from_file(str(DEFAULT_MODEL))
    tmp = spec.compile()
    d = mujoco.MjData(tmp)
    mujoco.mj_forward(tmp, d)

    added = 0
    for g in range(tmp.ngeom):
        if tmp.geom_type[g] != mujoco.mjtGeom.mjGEOM_MESH:
            continue
        mesh_name = mujoco.mj_id2name(tmp, mujoco.mjtObj.mjOBJ_MESH,
                                      tmp.geom_dataid[g]) or ""
        if mesh_name not in SHELL_RULES:
            continue
        body_id = tmp.geom_bodyid[g]
        body_name = mujoco.mj_id2name(tmp, mujoco.mjtObj.mjOBJ_BODY, body_id)

        # mesh 顶点 AABB（mesh 局部系）
        vadr, vnum = tmp.mesh_vertadr[tmp.geom_dataid[g]], tmp.mesh_vertnum[tmp.geom_dataid[g]]
        verts = tmp.mesh_vert[vadr:vadr + vnum] * 1000.0  # mm
        lo, hi = verts.min(axis=0), verts.max(axis=0)
        center = (lo + hi) / 2 * 0.001  # m
        extent = (hi - lo) * 0.001      # m
        longest = int(np.argmax(extent))

        gp = np.asarray(tmp.geom_pos[g])
        gq = np.asarray(tmp.geom_quat[g])
        # geom 旋转把 mesh 长轴（局部 z）映射到世界——capsule 复用同 quat，
        # 位置 = geom_pos + R(geom_quat) @ mesh_AABB_center
        R = np.zeros(9)
        mujoco.mju_quat2Mat(R, gq)
        R = R.reshape(3, 3)
        cap_pos = gp + R @ center

        body = spec.body(body_name)
        if mesh_name == "r_hand_plate":
            body.add_geom(
                type=mujoco.mjtGeom.mjGEOM_BOX,
                size=[extent[0] / 2, extent[1] / 2, extent[2] / 2],
                pos=[float(cap_pos[0]), float(cap_pos[1]), float(cap_pos[2])],
                quat=[float(gq[0]), float(gq[1]), float(gq[2]), float(gq[3])],
                contype=1, conaffinity=1, group=3,
                rgba=[0.2, 0.5, 1.0, 0.10], solref=[0.004, 1],
            )
            if verbose:
                print(f"  + palm box  [{body_name[:36]}] half={np.round(extent / 2 * 1000, 1)}mm")
        else:
            r = float(min(np.delete(extent, longest) / 2) * SHELL_RULES[mesh_name])
            half = max(0.005, extent[longest] / 2 - r)
            body.add_geom(
                type=mujoco.mjtGeom.mjGEOM_CAPSULE,
                size=[r, half, 0.0],
                pos=[float(cap_pos[0]), float(cap_pos[1]), float(cap_pos[2])],
                quat=[float(gq[0]), float(gq[1]), float(gq[2]), float(gq[3])],
                contype=1, conaffinity=1, group=3,
                rgba=[0.2, 0.5, 1.0, 0.10], solref=[0.004, 1],
            )
            if verbose:
                print(f"  + capsule   [{body_name[:36]}] mesh={mesh_name:14s} "
                      f"r={r * 1000:.1f}mm len={extent[longest] * 1000:.0f}mm")
        added += 1

    model = spec.compile()
    if verbose:
        print(f"injected: {added} collision geoms (total {model.ngeom})")
    return model


if __name__ == "__main__":
    m = build_collision_model(verbose=True)
    d = mujoco.MjData(m)
    mujoco.mj_forward(m, d)
    n_open = d.ncon
    print(f"open-pose contacts = {n_open}（应≈0：初始壳体不互相嵌住）")
    # 抓取姿态稳定性
    d.ctrl[:] = np.radians([90, -10, 90, -10, 90, -10, 90, -5])
    for _ in range(2000):
        mujoco.mj_step(m, d)
    print(f"grasp pose: finite={np.all(np.isfinite(d.qpos))}, "
          f"max|qacc|={np.abs(d.qacc).max():.3f}, ncon={d.ncon}")
