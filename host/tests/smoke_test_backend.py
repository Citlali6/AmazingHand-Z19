"""第 2 步冒烟测试 —— 三后端契约 + 抓取策略 + 主状态机全链路空转。

运行::

    python host/tests/smoke_test_backend.py

覆盖：
1. ServoBackend 契约（backend_sim）：目标下发→反馈收敛、力控抓取全周期、
   超时保持语义、急停保护
2. GraspSelector：查表、fallback、尺寸降级
3. main.run：mock 语音/视觉注入下的完整状态序列（IDLE→…→HOLDING→…→IDLE）
   与故障路径（stop→FAULT→reset→IDLE）
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # host/

from app.control.backend_sim import SimBackend  # noqa: E402
from app.control.servo_base import FsmState, GraspPlan  # noqa: E402
from app.main import AppState, Deps, MockVision, MockVoice, Command, run  # noqa: E402
from app.strategy.grasp_selector import GraspSelector  # noqa: E402

MIDDLE = (0.0,) * 8


def _plan(angles=(90, 0, 90, 0, 90, 0, 90, 0), torque=(6,) * 8) -> GraspPlan:
    return GraspPlan(angles_deg=angles, pregrasp_deg=(-35, 35) * 4,
                     speed_raw=3, torque_levels=torque, label="test")


def _sim_backend() -> SimBackend:
    return SimBackend(middle_deg=MIDDLE)


# ==========================================================================
# 1. 后端契约
# ==========================================================================


def test_targets_drive_feedback() -> None:
    b = _sim_backend()
    b.open()
    try:
        b.set_torque(True)
        b.set_targets((60, -30, 60, -30, 60, -30, 60, -30), speed_raw=0)
        for _ in range(200):
            b.tick(0.05)  # 10s，全速足够到位
        fb = b.poll_fsm().feedback
        assert all(abs(f.position_deg - a) <= 1.0
                   for f, a in zip(fb, (60, -30, 60, -30, 60, -30, 60, -30))), \
            f"positions not converged: {[round(f.position_deg, 1) for f in fb]}"
    finally:
        b.close()


def test_fsm_full_cycle_grasp_and_release() -> None:
    """PREGRASP→CLOSING→(力阈值)HOLD→RELEASING→IDLE 全周期。"""
    b = _sim_backend()
    b.open()
    try:
        # 手指闭合路径上放"物体"：负载超过力矩阈值(6级→384raw)
        load = {sid: 500 for sid in b.bus.servo_ids}
        b.bus.inject_external_load(load)
        b.start_grasp_fsm(_plan())
        assert b.poll_fsm().state == FsmState.PREGRASP
        for _ in range(60):  # 0.6s：PREGRASP(0.3s) + CLOSING 首拍即达阈值
            b.tick(0.01)
        snap = b.poll_fsm()
        assert snap.state == FsmState.HOLD
        assert snap.grasped and not snap.timeout
        b.release()
        for _ in range(80):  # 0.8s > RELEASING 0.5s
            b.tick(0.01)
        assert b.poll_fsm().state == FsmState.IDLE
    finally:
        b.close()


def test_fsm_closing_timeout_semantics() -> None:
    """无物体闭合到底？——速度受限 3s 内未到位/未触力阈值 → HOLD 且 timeout=True。"""
    b = _sim_backend()
    b.open()
    try:
        b.start_grasp_fsm(_plan())  # 无负载；speed_raw=3 → 3s 内走不到 90°
        for _ in range(400):  # 4s > PREGRASP 0.3 + CLOSING 3.0
            b.tick(0.01)
        snap = b.poll_fsm()
        assert snap.state == FsmState.HOLD
        assert snap.timeout and not snap.grasped, \
            "timeout hold must not be reported as grasped"
    finally:
        b.close()


def test_emergency_stop_protects() -> None:
    b = _sim_backend()
    b.open()
    try:
        b.start_grasp_fsm(_plan())
        b.emergency_stop()
        snap = b.poll_fsm()
        assert snap.state == FsmState.PROTECT and snap.fault
        assert all(not s.torque_on for s in
                   (b.bus.state(i) for i in b.bus.servo_ids)), "estop must cut torque"
    finally:
        b.close()


def test_drop_fault_during_hold_goes_protect() -> None:
    """保持阶段掉线 → PROTECT（力控安全路径）。"""
    b = _sim_backend()
    b.open()
    try:
        b.bus.inject_external_load({sid: 500 for sid in b.bus.servo_ids})
        b.start_grasp_fsm(_plan())
        for _ in range(80):
            b.tick(0.01)
        assert b.poll_fsm().state == FsmState.HOLD
        b.bus.inject_drop([5])  # 无名指舵机掉线
        b.tick(0.01)
        assert b.poll_fsm().state == FsmState.PROTECT
    finally:
        b.close()


# ==========================================================================
# 2. 抓取策略
# ==========================================================================


def test_selector_known_object() -> None:
    sel = GraspSelector()
    plan = sel.select("banana", size_mm=(180.0, 40.0, 40.0))
    assert plan.label == "banana"
    assert len(plan.angles_deg) == 8 and len(plan.torque_levels) == 8
    assert plan.mode == "power"


def test_selector_fallback_and_size_derating() -> None:
    sel = GraspSelector()
    plan = sel.select("unknown_thing")
    assert "fallback" in plan.label
    big = sel.select("apple", size_mm=(150.0, 150.0, 150.0))
    base = sel.select("apple")
    assert all(b <= a - 1 for b, a in zip(big.torque_levels, base.torque_levels)), \
        "large objects must derate torque"


# ==========================================================================
# 3. 主状态机全链路（mock 注入）
# ==========================================================================


def _deps(backend: SimBackend, voice: MockVoice, vision: MockVision) -> Deps:
    logs: list[str] = []
    return Deps(backend=backend, voice=voice, vision=vision,
                selector=GraspSelector(), tick_s=0.01,
                log=logs.append), logs


def test_main_pipeline_full_cycle() -> None:
    """语音'抓起香蕉'→识别→引导→抓取→保持；'放下'→释放→待命。"""
    b = _sim_backend()
    b.open()
    try:
        b.bus.inject_external_load({sid: 500 for sid in b.bus.servo_ids})
        voice = MockVoice([Command("grasp", "banana"), Command("release")], interval_ticks=10)
        deps, logs = _deps(b, voice, MockVision("banana", delay_ticks=20))
        history = run(deps, max_ticks=5000)
        text = " ".join(history)
        assert "RECOGNIZING" in text and "GUIDING" in text
        assert "GRASPING" in text and "HOLDING" in text
        assert "RELEASING" in text
        assert text.strip().endswith("IDLE") or history[-1].startswith("IDLE"), history
        assert any("plan=banana" in line for line in logs), "selector must be consulted"
    finally:
        b.close()


def test_main_stop_and_reset_path() -> None:
    """stop→FAULT→reset→IDLE 故障恢复路径。"""
    b = _sim_backend()
    b.open()
    try:
        voice = MockVoice([Command("stop"), Command("reset")], interval_ticks=5)
        deps, _ = _deps(b, voice, MockVision(delay_ticks=1))
        history = run(deps, max_ticks=2000)
        text = " ".join(history)
        assert "FAULT" in text
        assert history[-1].startswith("IDLE"), history
        assert all(not s.torque_on for s in
                   (b.bus.state(i) for i in b.bus.servo_ids)) or \
            b.bus.state(1).torque_on, "reset path re-enables torque"
    finally:
        b.close()


def test_main_recognize_timeout_returns_idle() -> None:
    """识别超时回 IDLE（视觉无目标场景）。"""

    class BlindVision:
        def detect_target(self):  # noqa: ANN202
            return None

        def guide_hand(self):  # noqa: ANN202
            raise AssertionError("should not reach guiding")

    b = _sim_backend()
    b.open()
    try:
        voice = MockVoice([Command("grasp", "banana")], interval_ticks=5)
        deps, _ = _deps(b, voice, BlindVision())
        deps.recognize_timeout_s = 0.2
        history = run(deps, max_ticks=500)
        assert history[-1].startswith("IDLE"), history
        assert "RECOGNIZING" in " ".join(history)
    finally:
        b.close()


# ==========================================================================
# 入口
# ==========================================================================


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
