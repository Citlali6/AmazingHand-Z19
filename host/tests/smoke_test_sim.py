"""第 3 步冒烟测试 —— MuJoCo 数字孪生验证链路。

前置：``pip install mujoco pillow``（PC 工具链依赖，见 requirements.txt）

运行::

    python host/tests/smoke_test_sim.py

覆盖：模型加载与执行器映射、姿态收敛、批量验证报告、姿态 API。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "host"))       # app 包
sys.path.insert(0, str(REPO_ROOT / "sim"))        # verify_grasp

from verify_grasp import DEFAULT_TABLE, HandSim, verify_table  # noqa: E402


def test_model_loads_and_maps_servos() -> None:
    sim = HandSim()
    assert sim.model.nu == 8
    expect = [f"finger{i}_motor{j}" for i in range(1, 5) for j in (1, 2)]
    assert sim.actuator_names == expect, f"actuator order mismatch: {sim.actuator_names}"
    assert all(tid >= 0 for tid in sim.tip_ids), "tip1..tip4 sites must exist"


def test_zero_pose_converges() -> None:
    sim = HandSim()
    sim.apply_pose((0.0,) * 8)
    assert sim.settle(0.5), "zero pose must converge quickly"
    res = sim.metrics("zero")
    assert res.all_reachable and res.self_contacts == 0
    assert 10.0 < res.min_gap_mm < 200.0, f"unreasonable tip gap: {res.min_gap_mm}"


def test_close_pose_reduces_gap() -> None:
    """闭合姿态的指尖间距应小于张开姿态（包络方向性）。"""
    sim = HandSim()
    sim.apply_pose((-35, 35, -35, 35, -35, 35, -35, 35))
    sim.settle(0.8)
    open_gap = sim.metrics("open").min_gap_mm
    sim.data.ctrl[:] = 0
    sim.apply_pose((90, -10, 90, -10, 90, -10, 90, -5))
    sim.settle(1.2)
    close_gap = sim.metrics("close").min_gap_mm
    assert close_gap < open_gap, f"close {close_gap:.1f}mm should < open {open_gap:.1f}mm"


def test_verify_table_full_report() -> None:
    out = REPO_ROOT / "data/metrics/grasp_table_validation_smoke.json"
    report = verify_table(DEFAULT_TABLE, out)
    entries = report["entries"]
    assert {"default", "banana", "apple", "bottle"} <= set(entries)
    for label, v in entries.items():
        assert v["converged"], f"{label} not converged"
        assert v["pass"] or v["limit_hits"] > 0, \
            f"{label}: fail without limit_hits means unexpected problem"
    reloaded = json.loads(out.read_text(encoding="utf-8"))
    assert set(reloaded["entries"]) == set(entries)


def test_middle_offset_applied() -> None:
    """标定中位角（相对模型零位）应整体平移指尖位置（标定链路占位验证）。"""
    middle = (5.0,) * 8
    sim = HandSim()
    sim.apply_pose((0.0,) * 8, middle)
    sim.settle(0.8)
    res = sim.metrics("mid", middle)
    assert res.all_reachable, "small middle offset must stay reachable"


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
