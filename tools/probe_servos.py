"""舵机总线探测 —— 拓扑/存活/型号扫描（实物到手第一件事）。

用途（对照 interface.md 待定项 3/拓扑确认）：
- 扫描 ID 1..20：逐个 PING，报告存活舵机的型号/固件/位置；
- **拓扑判定**：一条串口线上探到几个 ID → 反推接线形态：
    · 每线 1 个 ID = 8 路独立（每舵机独立引出）
    · 每线 2 个 ID = 4 路（每指 1 路，2 舵机并联）
    · 每线 8 个 ID = 1 条总线（官方默认拓扑）
- 读位置回读 → 确认协议层（scs_protocol.py）与真实舵机逐字节兼容。

接线（STM32 板串口方案）：
    舵机/绿板 DATA ←→ STM32 RX 直连 + STM32 TX 经 1kΩ 电阻接 DATA
    舵机电源 5V 独立供电，STM32 GND 必须与舵机 GND 共地！
    波特率 1Mbps（SCS0009 默认）。

运行::

    python tools/probe_servos.py --port COM5
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "host"))

from app.control import scs_protocol as sp  # noqa: E402

SCAN_IDS = range(1, 21)  # 官方约定 ID 1..8，扫到 20 以防改装


def ping(port, sid: int) -> dict | None:
    """PING 单个 ID，返回 (型号, 固件)。"""
    port.write(sp.build_ping(sid))
    port.flush()
    t0 = time.perf_counter()
    buf = bytearray()
    while time.perf_counter() - t0 < 0.05:
        n = port.in_waiting
        if n:
            buf += port.read(n)
            try:
                r = sp.parse_response(bytes(buf))
                return {"model": r.param_u16(0) if len(r.params) >= 2 else 0,
                        "fw": r.params[2] if len(r.params) >= 3 else 0}
            except sp.ProtocolError:
                continue
    return None


def read_feedback(port, sid: int) -> bytes | None:
    port.write(sp.build_read(sid, sp.Reg.FEEDBACK_ADDR, sp.Reg.FEEDBACK_LEN))
    port.flush()
    t0 = time.perf_counter()
    buf = bytearray()
    while time.perf_counter() - t0 < 0.05:
        n = port.in_waiting
        if n:
            buf += port.read(n)
            try:
                r = sp.parse_response(bytes(buf))
                return r.params
            except sp.ProtocolError:
                continue
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="SCS0009 总线探测")
    parser.add_argument("--port", required=True, help="串口号，如 COM5")
    parser.add_argument("--baud", type=int, default=1_000_000)
    args = parser.parse_args()

    try:
        import serial
    except ImportError:
        print("需要 pyserial：pip install pyserial")
        return 1

    ser = serial.Serial(args.port, args.baud, timeout=0.02)
    ser.reset_input_buffer()
    print(f"port={args.port} baud={args.baud}")
    print("扫描 ID 1..20（PING）...")
    alive: dict[int, dict] = {}
    for sid in SCAN_IDS:
        ser.reset_input_buffer()
        info = ping(ser, sid)
        if info:
            alive[sid] = info
            print(f"  ID {sid:2d}: 存活  型号raw={info['model']} 固件={info['fw']}")
    if not alive:
        print("未发现任何舵机——检查：①共地 ②TX 串 1kΩ ③供电 ④波特率 1Mbps")
        return 1

    print(f"\n存活 {len(alive)} 个：{sorted(alive)}")
    ids = sorted(alive)
    if len(ids) == 1:
        topo = "单舵机（测试单指）"
    elif len(ids) == 2:
        topo = "2 舵机/线 → 每指 1 路（4 总线拓扑）"
    elif len(ids) >= 8:
        topo = "8 舵机/线 → 单总线拓扑（与 interface.md v0.2 一致）"
    else:
        topo = f"{len(ids)} 舵机/线（非标准划分，记录待定）"
    print(f"拓扑判定（本线）：{topo}")

    print("\n位置回读（验证协议兼容性，3 次）：")
    for _ in range(3):
        row = []
        for sid in ids:
            fb = read_feedback(ser, sid)
            if fb and len(fb) >= 8:
                pos = fb[0] | (fb[1] << 8)
                load = fb[4] | (fb[5] << 8)
                temp = fb[7]
                row.append(f"#{sid}:pos={pos:4d} load={load:3d} T={temp}C")
        print("  " + " | ".join(row))
        time.sleep(0.3)

    print("\n下一步：tools/calibrate_servo.py 逐舵机行程/方向标定（待定项 1/2）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
