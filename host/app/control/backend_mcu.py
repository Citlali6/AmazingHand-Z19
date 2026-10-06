"""STM32 透传后端 —— PC 指令 → USB CDC → STM32 → 1Mbps 单总线 → SCS0009。

与 backend_serial 的关系：协议层（scs_protocol golden model）完全复用，
仅传输封装不同——帧长前缀协议 ``[len][bytes]``，响应 ``[len][bytes] | [0]``。

定位（架构叙事）：指令层（PC）与实时层（下位机）分离的下位机形态；
最终作品同构叙事 = PC 指令 → Z19 PL 硬件环（1kHz RTL）。

固件：tools/mcu_firmware/stm32_passthrough/stm32_passthrough.ino（STM32duino）。
"""

from __future__ import annotations

import math
import time
from typing import Iterable

from app.control import scs_protocol as sp
from app.control.servo_base import (
    N_JOINTS,
    FsmState,
    FsmSnapshot,
    GraspPlan,
    ServoBackend,
    ServoFeedback,
)


def deg_to_raw(deg: float, middle_deg: float) -> int:
    """占位换算：-180..+180 → 0..4095（真值待定项 1 实机标定）。"""
    frac = (deg + middle_deg + 180.0) / 360.0
    return max(0, min(sp.POSITION_STEPS, int(round(frac * sp.POSITION_STEPS))))


class McuBackend(ServoBackend):
    name = "mcu"

    def __init__(self, port: str = "COM5", baud: int = 2_000_000,
                 middle_deg: Iterable[float] = (0.0,) * N_JOINTS,
                 servo_ids: Iterable[int] = range(1, 9),
                 resp_timeout: float = 0.05):
        self._port_cfg = port
        self._baud = baud
        self._timeout = resp_timeout
        self.middle = tuple(middle_deg)
        self._ids = tuple(servo_ids)
        self._ser: object | None = None

    def open(self) -> None:
        try:
            import serial
        except ImportError as exc:
            raise RuntimeError("backend_mcu 需要 pyserial") from exc
        self._ser = serial.Serial(self._port_cfg, self._baud, timeout=0.02)
        time.sleep(0.5)  # 等 STM32 CDC 就绪
        self._ser.reset_input_buffer()

    def close(self) -> None:
        if self._ser is not None:
            try:
                self.set_torque(False)
            finally:
                self._ser.close()
                self._ser = None

    # ---- 透传事务：[len][帧] → [rlen][响应] ----

    def _transact(self, frame: bytes, expect_reply: bool) -> sp.Response | None:
        assert self._ser is not None
        self._ser.write(bytes([len(frame)]))
        self._ser.write(frame)
        self._ser.flush()
        if not expect_reply:
            return None
        deadline = time.perf_counter() + self._timeout
        while time.perf_counter() < deadline:
            n = self._ser.read(1)
            if not n:
                continue
            rlen = n[0]
            if rlen == 0:
                return None  # STM32 报告无响应
            body = bytearray()
            while len(body) < rlen and time.perf_counter() < deadline:
                chunk = self._ser.read(rlen - len(body))
                body += chunk
            try:
                return sp.parse_response(bytes(body))
            except sp.ProtocolError:
                continue  # 坏帧重试窗口内继续
        return None

    # ---- ServoBackend ----

    def set_torque(self, on: bool) -> None:
        for sid in self._ids:
            self._transact(
                sp.build_write(sid, sp.Reg.TORQUE_SWITCH[0], bytes([1 if on else 0])),
                True,
            )

    def set_targets(self, angles_deg: tuple[float, ...], speed_raw: int = 0) -> None:
        for i, sid in enumerate(self._ids):
            raw = deg_to_raw(angles_deg[i], self.middle[i])
            self._transact(sp.build_write_u16(sid, sp.Reg.GOAL_POSITION[0], raw), True)
            self._transact(sp.build_write_u16(sid, sp.Reg.RUNNING_SPEED[0], speed_raw), True)

    def start_grasp_fsm(self, plan: GraspPlan) -> None:
        self._plan = plan
        self._fsm = FsmState.PREGRASP
        self._state_t = 0.0
        self.set_torque(True)
        self.set_targets(plan.pregrasp_deg, plan.speed_raw)

    def release(self) -> None:
        if self._plan is not None and self._fsm in (FsmState.CLOSING, FsmState.HOLD):
            self._fsm = FsmState.RELEASING
            self._state_t = 0.0
            assert self._plan is not None
            self.set_targets(self._plan.pregrasp_deg, self._plan.speed_raw)

    def emergency_stop(self) -> None:
        self._fsm = FsmState.PROTECT
        self._plan = None
        self.set_torque(False)

    def poll_fsm(self) -> FsmSnapshot:
        feedback = self._read_feedback()
        err_bitmap = 0
        for i, fb in enumerate(feedback):
            if not fb.online:
                err_bitmap |= 1 << (i * 3 + 1)
            elif fb.error_bits & sp.ERR_OVERLOAD:
                err_bitmap |= 1 << (i * 3)
            elif fb.error_bits & sp.ERR_OVERHEAT:
                err_bitmap |= 1 << (i * 3 + 2)
        return FsmSnapshot(
            state=self._fsm,
            busy=self._fsm not in (FsmState.IDLE, FsmState.HOLD),
            grasped=self._fsm == FsmState.HOLD,
            fault=self._fsm == FsmState.PROTECT,
            err_bitmap=err_bitmap,
            loop_timestamp=self.read_loop_timestamp(),
            feedback=feedback,
        )

    def read_loop_timestamp(self) -> int:
        return time.perf_counter_ns()

    def tick(self, dt_s: float) -> None:
        self._state_t += dt_s
        plan = self._plan
        if plan is None:
            return
        if self._fsm == FsmState.PREGRASP and self._state_t >= 0.3:
            self.set_targets(plan.angles_deg, plan.speed_raw)
            self._fsm, self._state_t = FsmState.CLOSING, 0.0
        elif self._fsm == FsmState.CLOSING:
            fb = self._read_feedback()
            hit = any(
                f.online and f.load_raw >= plan.torque_levels[i] * 64
                for i, f in enumerate(fb)
            )
            if hit or self._state_t >= 3.0:
                self._fsm, self._state_t = FsmState.HOLD, 0.0
        elif self._fsm == FsmState.RELEASING and self._state_t >= 0.5:
            self._fsm, self._plan = FsmState.IDLE, None

    def _read_feedback(self) -> list[ServoFeedback]:
        out: list[ServoFeedback] = []
        for i, sid in enumerate(self._ids):
            fb = ServoFeedback(servo_id=sid, online=False)
            resp = self._transact(
                sp.build_read(sid, sp.Reg.FEEDBACK_ADDR, sp.Reg.FEEDBACK_LEN), True
            )
            if resp is not None and len(resp.params) == sp.Reg.FEEDBACK_LEN:
                pos_raw = resp.param_u16(0)
                fb = ServoFeedback(
                    servo_id=sid,
                    online=True,
                    position_raw=pos_raw,
                    position_deg=sp.raw_to_rad(pos_raw) * 180.0 / math.pi - self.middle[i],
                    load_raw=resp.param_u16(4),
                    temperature_c=float(resp.params[7]),
                    voltage_x10=resp.params[6],
                    error_bits=resp.error,
                )
            out.append(fb)
        return out
