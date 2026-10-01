"""RTL 环后端 —— AXI4-Lite 寄存器访问（/dev/mem mmap），作品核心链路。

寄存器映射 = ``docs/design/interface.md`` v0.2（唯一契约）::

    控制区: CTRL 0x00 | CMD 0x04 | TARGET_i 0x10+i*4 | TORQUE_LIM 0x30 | TIMING 0x34
    状态区: STATUS 0x80 | FSM_STATE 0x84 | MEAS_i 0x90+i*4 | LOAD 0xB0+i*2(半字×8)
            TEMP 0xD0 | ERR_BITMAP 0xE0 | TIMESTAMP 0xF0

- 仅 Linux 板端可用（/dev/mem）；Windows 上 open() 会报错（PC 冒烟用 sim 后端）；
- 角度 0.1° 定点编码细则属 interface.md 待定项 1，当前按
  ``val = round(deg*10) & 0xFFF``（相对中位、无符号偏置待标定）占位——
  定稿时本文件与 PL 侧同一批修订；
- 控制环时序完全由 PL 内 grasp_fsm/servo_bus_ctrl 硬件保证，
  本模块只做"写下发、读回读"，不参与实时调度（这正是对比实验的变量控制）。
"""

from __future__ import annotations

import math
from typing import Iterable

from app.control.servo_base import (
    N_JOINTS,
    FsmState,
    FsmSnapshot,
    GraspPlan,
    ServoBackend,
    ServoFeedback,
)

# ---- 寄存器偏移（interface.md v0.2） ----
REG_CTRL = 0x00  # [0] enable [1] mode [2] estop
REG_CMD = 0x04  # [7:0] cmd [15:8] arg；0x01 抓取 0x02 释放 0x03 预张 0x10 回中
REG_TARGET0 = 0x10  # +i*4: [11:0] 角度0.1° [15:12] 舵机ID
REG_TORQUE_LIM = 0x30  # 每 4 位一通道 0..15
REG_TIMING = 0x34  # [7:0] 闭合速度 [15:8] 轮询周期(×0.1ms)
REG_STATUS = 0x80  # [0] busy [1] grasped [2] timeout [3] fault
REG_FSM_STATE = 0x84
REG_MEAS0 = 0x90  # +i*4: [11:0] 角度 [15:12] 标志
REG_LOAD0 = 0xB0  # +i*2: 16 位半字 ×8（跨 32 位字对齐）
REG_TEMP = 0xD0
REG_ERR_BITMAP = 0xE0
REG_TIMESTAMP = 0xF0

DEFAULT_AXI_BASE = 0x4000_0000
_PAGE_SIZE = 4096


class AxilRegs:
    """AXI4-Lite 从接口的 /dev/mem 访问器（32bit 读写）。"""

    def __init__(self, base_addr: int = DEFAULT_AXI_BASE):
        self._base = base_addr
        self._map = None
        self._fd = None

    def open(self) -> None:
        import mmap
        import os

        self._fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        page = self._base & ~(_PAGE_SIZE - 1)
        offset = self._base - page
        self._map = mmap.mmap(self._fd, _PAGE_SIZE, mmap.MAP_SHARED,
                              mmap.PROT_READ | mmap.PROT_WRITE, offset=offset)

    def close(self) -> None:
        if self._map is not None:
            self._map.close()
            self._map = None
        if self._fd is not None:
            import os

            os.close(self._fd)
            self._fd = None

    def read32(self, offset: int) -> int:
        assert self._map is not None, "call open() first"
        return int.from_bytes(self._map[offset:offset + 4], "little")

    def write32(self, offset: int, value: int) -> None:
        assert self._map is not None, "call open() first"
        self._map[offset:offset + 4] = int(value & 0xFFFF_FFFF).to_bytes(4, "little")

    def read16(self, offset: int) -> int:
        """半字读：LOAD 区 0xB0+i*2 跨 32 位字，按对齐字读取后截取。"""
        word_off = offset & ~0x3
        shift = (offset - word_off) * 8
        return (self.read32(word_off) >> shift) & 0xFFFF


def enc_target(servo_id: int, angle_deg: float) -> int:
    """TARGET_i 编码：[15:12] ID + [11:0] 角度 0.1°（编码细则=待定项 1，占位）。"""
    deci = int(round(angle_deg * 10)) & 0xFFF
    return ((servo_id & 0xF) << 12) | deci


def dec_meas(word: int) -> tuple[int, int]:
    """MEAS_i 解码 → (位置 0.1°, 标志)。"""
    return word & 0xFFF, (word >> 12) & 0xF


class FpgaBackend(ServoBackend):
    name = "fpga"

    def __init__(self, axi_base: int = DEFAULT_AXI_BASE,
                 servo_ids: Iterable[int] = range(1, 9),
                 poll_period_units: int = 10):  # 10×0.1ms = 1kHz（interface.md §6）
        self._regs = AxilRegs(axi_base)
        self._ids = tuple(servo_ids)
        self._poll_units = poll_period_units

    def open(self) -> None:
        self._regs.open()
        # TIMING：轮询周期 1kHz 默认；闭合速度由 GraspPlan 逐次下发
        self._regs.write32(REG_TIMING, (self._poll_units & 0xFF) << 8)

    def close(self) -> None:
        self.emergency_stop()
        self._regs.close()

    # -- ServoBackend 接口 ----------------------------------------------

    def set_torque(self, on: bool) -> None:
        # CMD=0x04 力矩使能（arg 1=使能 0=断开）——interface.md §3 CMD 扩展，v0.2.1 起生效
        self._regs.write32(REG_CMD, ((0x01 if on else 0x00) << 8) | 0x04)

    def set_targets(self, angles_deg: tuple[float, ...], speed_raw: int = 0) -> None:
        # 直接角度模式：CTRL.mode=0
        ctrl = self._regs.read32(REG_CTRL)
        self._regs.write32(REG_CTRL, (ctrl & ~0x2) | 0x1)
        for i, sid in enumerate(self._ids):
            self._regs.write32(REG_TARGET0 + i * 4, enc_target(sid, angles_deg[i]))
        self._regs.write32(REG_TIMING, ((self._poll_units & 0xFF) << 8) | (speed_raw & 0xFF))

    def start_grasp_fsm(self, plan: GraspPlan) -> None:
        # 状态机模式：写目标/力矩/时序 → CTRL.mode=1 → CMD=0x01
        for i, sid in enumerate(self._ids):
            self._regs.write32(REG_TARGET0 + i * 4, enc_target(sid, plan.angles_deg[i]))
        torque_word = 0
        for i in range(N_JOINTS):
            torque_word |= (plan.torque_levels[i] & 0xF) << (4 * i)
        self._regs.write32(REG_TORQUE_LIM, torque_word)
        self._regs.write32(REG_TIMING,
                           ((self._poll_units & 0xFF) << 8) | (plan.speed_raw & 0xFF))
        ctrl = self._regs.read32(REG_CTRL)
        self._regs.write32(REG_CTRL, ctrl | 0x2 | 0x1)  # mode=1, enable=1
        self._regs.write32(REG_CMD, 0x01)

    def release(self) -> None:
        self._regs.write32(REG_CMD, 0x02)

    def emergency_stop(self) -> None:
        ctrl = self._regs.read32(REG_CTRL)
        self._regs.write32(REG_CTRL, ctrl | 0x4)  # estop=1

    def poll_fsm(self) -> FsmSnapshot:
        status = self._regs.read32(REG_STATUS)
        feedback = self._read_feedback()
        return FsmSnapshot(
            state=FsmState(self._regs.read32(REG_FSM_STATE) & 0xFF),
            busy=bool(status & 0x1),
            grasped=bool(status & 0x2),
            timeout=bool(status & 0x4),
            fault=bool(status & 0x8),
            err_bitmap=self._regs.read32(REG_ERR_BITMAP),
            loop_timestamp=self._regs.read32(REG_TIMESTAMP),
            feedback=feedback,
        )

    def read_loop_timestamp(self) -> int:
        return self._regs.read32(REG_TIMESTAMP)

    def _read_feedback(self) -> list[ServoFeedback]:
        temp_word = self._regs.read32(REG_TEMP)
        feedback: list[ServoFeedback] = []
        for i, sid in enumerate(self._ids):
            pos_deci, flags = dec_meas(self._regs.read32(REG_MEAS0 + i * 4))
            online = not (flags & 0x1)  # 标志位布局与 PL 约定：bit0=offline（待定稿）
            feedback.append(ServoFeedback(
                servo_id=sid,
                online=online,
                position_raw=pos_deci,  # 占位：0.1°→raw 换算属待定项 1，联调时统一
                position_deg=pos_deci * 0.1,
                load_raw=self._regs.read16(REG_LOAD0 + i * 2),
                temperature_c=float((temp_word >> 8) & 0xFF) if i == (temp_word & 0xFF) else 0.0,
                voltage_x10=0,
                error_bits=flags,
            ))
        return feedback
