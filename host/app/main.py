"""主状态机 —— 待命 → 识别 → 引导 → 抓取 → 保持 → 释放（architecture.md 数据流落地）。

无硬件阶段运行方式（PC，backend=sim，全部 mock 输入）::

    python host/app/main.py --mock-voice "抓起香蕉,放下"

语音基础入口（真实输入仅接sim，视觉仍为Mock；不是PL/MuJoCo验收）::

    python -m app.main --backend sim --mic
    python -m app.voice listen         # 板端独立识别输出，不连接控制

设计要点：
- 依赖全部经构造注入（``Deps``）：voice/vision 用 :class:`VoiceSource` /
  :class:`VisionSource` 协议抽象，正式模块（kws.py / detector.py）落地后替换
  Mock 实现即可，状态机零改动；
- ``run()`` 显式 tick 驱动、返回状态历史——确定性可测（冒烟断言状态序列）；
- 后端切换 = settings.yaml 一行（backend_sim/serial/fpga 实现同一接口）。
"""

from __future__ import annotations

import argparse
import sys
import time
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Callable, Protocol

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # host/（直接脚本运行时）

from app.control.servo_base import FsmState, GraspPlan, ServoBackend  # noqa: E402
from app.strategy.grasp_selector import DEFAULT_TABLE, GraspSelector  # noqa: E402

# ------------------------------------------------------------------
# 数据契约
# ------------------------------------------------------------------


class AppState(str, Enum):
    IDLE = "IDLE"
    RECOGNIZING = "RECOGNIZING"
    GUIDING = "GUIDING"
    GRASPING = "GRASPING"
    HOLDING = "HOLDING"
    RELEASING = "RELEASING"
    FAULT = "FAULT"


@dataclass(frozen=True)
class Command:
    """语音模块输出：结构化指令（project_framework F1）。"""

    action: str  # grasp / release / stop / reset
    target: str = ""


@dataclass(frozen=True)
class Detection:
    """视觉模块输出：目标物体（F2）。"""

    category: str
    size_mm: tuple[float, float, float]
    yaw_deg: float = 0.0


@dataclass(frozen=True)
class GuideResult:
    """ArUco 就位引导输出（F2c）：偏移与就位判定。"""

    in_position: bool
    dx_cm: float = 0.0
    dy_cm: float = 0.0
    dyaw_deg: float = 0.0


class VoiceSource(Protocol):
    def poll_command(self) -> Command | None: ...


class VisionSource(Protocol):
    def detect_target(self) -> Detection | None: ...
    def guide_hand(self) -> GuideResult: ...


@dataclass
class Deps:
    backend: ServoBackend
    voice: VoiceSource
    vision: VisionSource
    selector: GraspSelector
    tick_s: float = 0.01
    recognize_timeout_s: float = 5.0
    guide_timeout_s: float = 30.0
    log: Callable[[str], None] = print
    realtime: bool = False
    poll_every_tick: bool = False


# ------------------------------------------------------------------
# Mock 实现（PC 冒烟；正式模块落地后整体替换）
# ------------------------------------------------------------------


class MockVoice:
    """脚本化命令队列：按 tick 节拍逐个吐出。"""

    def __init__(self, commands: list[Command], interval_ticks: int = 10):
        self._queue = list(commands)
        self._interval = interval_ticks
        self._countdown = 0

    def poll_command(self) -> Command | None:
        if self._countdown > 0 or not self._queue:
            self._countdown = max(0, self._countdown - 1)
            return None
        self._countdown = self._interval
        return self._queue.pop(0)


class MockVision:
    """固定目标 + 延迟就位：前 ``delay_ticks`` 拍给偏移，之后判定就位。"""

    def __init__(self, category: str = "banana", delay_ticks: int = 20):
        self.category = category
        self._delay = delay_ticks
        self._seen = 0

    def detect_target(self) -> Detection | None:
        return Detection(category=self.category, size_mm=(180.0, 40.0, 40.0))

    def guide_hand(self) -> GuideResult:
        self._seen += 1
        if self._seen > self._delay:
            return GuideResult(in_position=True)
        return GuideResult(in_position=False, dx_cm=2.0 * (self._delay - self._seen))


# ------------------------------------------------------------------
# 主状态机
# ------------------------------------------------------------------


def run(deps: Deps, max_ticks: int = 100_000) -> list[str]:
    """主循环：返回状态历史（含迁移原因标记，供测试断言与日志）。"""
    history: list[str] = [AppState.IDLE.value]
    state = AppState.IDLE
    plan: GraspPlan | None = None
    target = ""
    state_t = 0.0

    def goto(next_state: AppState, note: str = "") -> None:
        nonlocal state, state_t
        state = next_state
        state_t = 0.0
        deps.log(f"[{next_state.value}] {note}")
        history.append(next_state.value + (f"({note})" if note else ""))

    next_tick = time.monotonic()
    for _ in range(max_ticks):
        if deps.realtime:
            time.sleep(max(0, next_tick - time.monotonic()))
            next_tick = max(next_tick + deps.tick_s, time.monotonic())
        deps.backend.tick(deps.tick_s)
        state_t += deps.tick_s
        live_cmd = deps.voice.poll_command() if deps.poll_every_tick else None
        if live_cmd is not None and live_cmd.action == 'stop':
            deps.backend.emergency_stop()
            goto(AppState.FAULT, 'voice: stop')
            continue
        if (live_cmd is not None and live_cmd.action == 'release'
                and state in (AppState.RECOGNIZING, AppState.GUIDING, AppState.GRASPING, AppState.HOLDING)):
            deps.backend.release()
            goto(AppState.RELEASING, 'voice: release')
            continue

        if state == AppState.IDLE:
            cmd = live_cmd if deps.poll_every_tick else deps.voice.poll_command()
            if cmd is None:
                continue
            if cmd.action == "grasp":
                target = cmd.target
                goto(AppState.RECOGNIZING, f"voice: grasp {target}")
            elif cmd.action == "stop":
                deps.backend.emergency_stop()
                goto(AppState.FAULT, "voice: stop")
            elif cmd.action == "reset":
                deps.log("idle: nothing to reset")

        elif state == AppState.RECOGNIZING:
            if state_t > deps.recognize_timeout_s:
                goto(AppState.IDLE, "recognize timeout")
                continue
            det = deps.vision.detect_target()
            if det is None:
                continue
            if target and det.category != target:
                continue
            plan = deps.selector.select(det.category, det.size_mm, det.yaw_deg)
            goto(AppState.GUIDING, f"plan={plan.label} mode={plan.mode}")

        elif state == AppState.GUIDING:
            if state_t > deps.guide_timeout_s:
                goto(AppState.IDLE, "guide timeout")
                continue
            guide = deps.vision.guide_hand()
            if guide.in_position:
                assert plan is not None
                deps.backend.start_grasp_fsm(plan)
                goto(AppState.GRASPING, "in position, grasp started")
            else:
                if int(state_t / deps.tick_s) % 50 == 0:  # 节流引导打印
                    deps.log(
                        f"guide: dx={guide.dx_cm:+.1f}cm dy={guide.dy_cm:+.1f}cm"
                        f" dyaw={guide.dyaw_deg:+.1f}°"
                    )

        elif state == AppState.GRASPING:
            snap = deps.backend.poll_fsm()
            if snap.fault:
                deps.backend.emergency_stop()
                goto(AppState.FAULT, f"err_bitmap=0x{snap.err_bitmap:X}")
            elif snap.grasped:
                goto(AppState.HOLDING, "grasped")
            elif snap.timeout:
                goto(AppState.HOLDING, "closing timeout (held at obstacle)")

        elif state == AppState.HOLDING:
            cmd = live_cmd if deps.poll_every_tick else deps.voice.poll_command()
            if cmd is None:
                continue
            if cmd.action == "release":
                deps.backend.release()
                goto(AppState.RELEASING, "voice: release")
            elif cmd.action == "stop":
                deps.backend.emergency_stop()
                goto(AppState.FAULT, "voice: stop")

        elif state == AppState.RELEASING:
            snap = deps.backend.poll_fsm()
            if snap.state == FsmState.IDLE:
                plan = None
                goto(AppState.IDLE, "released")

        elif state == AppState.FAULT:
            cmd = live_cmd if deps.poll_every_tick else deps.voice.poll_command()
            if cmd is not None and cmd.action == "reset":
                deps.backend.set_torque(True)
                goto(AppState.IDLE, "manual reset")

        else:  # pragma: no cover
            goto(AppState.FAULT, "unknown state")

    return history


# ------------------------------------------------------------------
# 装配与 CLI
# ------------------------------------------------------------------


def load_settings(path: Path | None = None) -> dict:
    """读 settings.yaml；缺失/损坏时回退内置默认（PC 冒烟不依赖配置存在）。"""
    cfg_path = path or (Path(__file__).resolve().parents[1] / "config" / "settings.yaml")
    default = {
        "backend": "sim",
        "serial": {"port": "/dev/ttyUSB0", "baudrate": 1000000, "timeout_s": 0.05},
        "fpga": {"axi_base": "0x40000000", "poll_period_units": 10},
        "servo": {
            "ids": [1, 2, 3, 4, 5, 6, 7, 8],
            "middle_pos_deg": [3, 0, -5, -8, -2, 5, -12, 0],
        },
        "strategy": {"table": "grasp_table.json"},
        "app": {"tick_hz": 100, "recognize_timeout_s": 5.0, "guide_timeout_s": 30.0},
    }
    if not cfg_path.exists():
        return default
    try:
        import yaml

        loaded = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    except Exception as exc:  # noqa: BLE001 —— 配置损坏时保底默认
        print(f"warn: settings.yaml 读取失败（{exc}），使用内置默认", file=sys.stderr)
        return default
    for k, v in default.items():
        loaded.setdefault(k, v)
    return loaded


def build_backend(name: str, settings: dict) -> ServoBackend:
    """后端工厂：换硬件只改 settings.yaml（architecture.md 规则 1）。"""
    from app.control.backend_sim import SimBackend

    middle = tuple(settings["servo"]["middle_pos_deg"])
    ids = tuple(settings["servo"]["ids"])
    if name == "sim":
        return SimBackend(middle_deg=middle, servo_ids=ids)
    if name == "serial":
        from app.control.backend_serial import SerialBackend

        s = settings["serial"]
        return SerialBackend(port=s["port"], baudrate=int(s["baudrate"]),
                             timeout_s=float(s["timeout_s"]), middle_deg=middle,
                             servo_ids=ids)
    if name == "fpga":
        from app.control.backend_fpga import FpgaBackend

        f = settings["fpga"]
        return FpgaBackend(axi_base=int(f["axi_base"], 0), servo_ids=ids,
                           poll_period_units=int(f["poll_period_units"]))
    raise ValueError(f"unknown backend: {name}")


# 命令词解析已收敛到 app/voice/kws.py（语音正式链路），此处复用
from app.voice.kws import parse_zh_command  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if "--mujoco" in arguments:
        arguments.remove("--mujoco")
        sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
        from sim.host_demo import main as run_mujoco

        return run_mujoco(arguments)
    parser = argparse.ArgumentParser(description="AmazingHand AI host 主程序")
    parser.add_argument("--mujoco", action="store_true", help="实时交互 MuJoCo；其余选项见 --mujoco --help")
    parser.add_argument("--backend", choices=["sim", "serial", "fpga"], default=None)
    voice_inputs = parser.add_mutually_exclusive_group()
    voice_inputs.add_argument("--mock-voice", default=None,
                        help='mock 语音脚本，逗号分隔，如 "抓起香蕉,放下"')
    voice_inputs.add_argument('--mic', action='store_true', help='Linux USB麦克风输入（本阶段仅sim后端）')
    voice_inputs.add_argument('--voice-wav', type=Path, help='单条命令WAV回放（本阶段仅sim后端）')
    parser.add_argument('--voice-config', type=Path, help='voice_usb.json路径')
    parser.add_argument('--voice-device', help='ALSA plughw录音设备名')
    parser.add_argument('--voice-model', type=Path, help='Vosk中文模型目录')
    parser.add_argument('--seconds', type=float, default=60, help='真实语音输入的运行时长，秒')
    parser.add_argument("--config", default=None, help="settings.yaml 路径")
    args = parser.parse_args(argv)

    settings = load_settings(Path(args.config) if args.config else None)
    backend_name = args.backend or settings["backend"]
    real_voice = args.mic or args.voice_wav is not None
    if real_voice and backend_name != 'sim':
        parser.error('语音基础阶段仅允许 --backend sim；MJC1需通过现有控制进程接入，不能直接使用旧fpga后端。')
    if real_voice and not 0 < args.seconds <= 3600:
        parser.error('--seconds must be >0 and <=3600')
    selector = GraspSelector(DEFAULT_TABLE)

    if args.mock_voice is not None:
        cmds = [c for c in (parse_zh_command(t.strip()) for t in args.mock_voice.split(",")) if c]
        voice: VoiceSource = MockVoice(cmds)
    elif real_voice:
        from app.voice.__main__ import DEFAULT_CONFIG, configuration, microphone, recognizer
        config = configuration(args.voice_config or DEFAULT_CONFIG)
        if args.mic:
            voice = microphone(config, args.voice_model, args.voice_device)
        else:
            command = recognizer(config, args.voice_model).command_from_wav(args.voice_wav)
            if command is None:
                raise SystemExit('录音没有通过命令词/置信度检查，未执行动作。')
            voice = MockVoice([command])
    else:
        raise SystemExit('请选择 --mock-voice、--mic 或 --voice-wav；仅识别输出请运行 python -m app.voice。')

    try:
        app_cfg = settings["app"]
        backend = build_backend(backend_name, settings)
        tick_s = 1.0 / float(app_cfg['tick_hz'])
        deps = Deps(
            backend=backend, voice=voice, vision=MockVision(), selector=selector,
            tick_s=tick_s, recognize_timeout_s=float(app_cfg['recognize_timeout_s']),
            guide_timeout_s=float(app_cfg['guide_timeout_s']),
            realtime=args.mic, poll_every_tick=real_voice)
        with backend:
            try:
                history = run(deps, max_ticks=max(1, int(args.seconds / tick_s)) if real_voice else 200_000)
            finally:
                if real_voice:
                    backend.emergency_stop()
    finally:
        if hasattr(voice, 'close'):
            voice.close()
    print("state history:", " → ".join(history))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
