# PR #001 — SCS 协议 golden model + 虚拟舵机总线 + 冒烟测试

> **复制本文件内容到 GitHub PR 描述框即可创建 PR。**
> 分支：`feat/scs-protocol-golden-model` → `plan`
> 状态：Draft（可评审）· 关联契约：`docs/design/interface.md` v0.2 §6

---

## 概述

无硬件阶段的协议层交付：Feetech SCS 系列协议的 **Python golden model**、**虚拟舵机总线**与 **25 用例冒烟测试**。后续 RTL（`scs_protocol.sv` / `scs_slave_model.sv`）以本实现为逐字节比对基准，`tools/calibrate_servo.py` 复用其组包函数。

## 提交清单

| Commit | 内容 |
|---|---|
| `1d5e32d` | docs: 接口契约 v0.2（单总线拓扑定稿 + 引脚分配 + 时隙调度）+ Z19 关键规格摘录 |
| `d59b9a8` | feat(host): SCS 协议 golden model + 虚拟舵机总线 + 冒烟测试 25 用例全过 |
| （本 PR） | docs: PR 文档与开发日志 |

## 新增文件

```
host/app/__init__.py
host/app/control/__init__.py
host/app/control/scs_protocol.py    # SCS 协议 golden model（组包/解包/校验和/寄存器表/单位换算）
host/app/control/scs_sim.py         # 虚拟舵机总线（帧进帧出 + 确定性 step + 故障注入）
host/tests/smoke_test_control.py    # 冒烟测试（零第三方依赖，pytest 兼容）
docs/pr/001-scs-protocol-golden-model.md
docs/log/2026-10-01.md
```

文档同步：`docs/design/architecture.md` 文件树补齐 control 三模块与 `host/tests/`；`docs/design/interface.md` §6 时隙预算按真实帧长修正（SYNC_WRITE 48B / READ 20B，1kHz 预算 980µs 成立）。

## 设计要点

### 1. `scs_protocol.py`（golden model）

- 帧格式：`FF FF ID LENGTH INSTRUCTION PARAM... CHECKSUM`，`LENGTH = len(PARAM)+2`，`CHECKSUM = ~(ID+LENGTH+INS+PARAM...) & 0xFF`
- 指令覆盖：PING / READ / WRITE / REG_WRITE / ACTION / RESET / SYNC_WRITE(0x83)
- `Reg` 类集中管理 SCS0009 寄存器地址与宽度；力控一条 READ 时隙取回全部反馈的连读视图 `FEEDBACK_ADDR=0x3A, FEEDBACK_LEN=8`
- rad↔raw 换算与上游 rustypot `Scs0009PyController` 行为对齐（raw 0..4095 ↔ -π..+π）
- 解析容忍前导垃圾字节（UART 缓冲残渣），坏校验和抛 `ProtocolError`

### 2. `scs_sim.py`（虚拟舵机总线）

- 接口形状 = 半双工总线真实行为：`transact(frame) -> bytes | None`（一问一答，广播/掉线/垃圾帧返回 None）
- 所有物理演化由显式 `step(dt)` 推进——**同帧序列必得同响应序列**，可作为 RTL TB 的行为参考
- 故障注入：`inject_drop`（掉线超时语义）、`inject_external_load`（夹持阻力→堵转判定）、过温自动切断并拒绝重新使能（Alarm_Shutdown 语义）
- 虚拟动力学覆盖：位置限速逼近、负载合成、温度积分

### 3. 冒烟测试（25 用例，四组）

| 组 | 覆盖 |
|---|---|
| 协议组包 | 手工校验和锚点帧（防"错得一致"）、SYNC_WRITE 32B/2 舵机、rad↔raw 往返 |
| 解析鲁棒性 | 前导垃圾、坏校验和、截断帧、无帧头 |
| 总线闭环 | PING、写目标→步进→回读收敛、限速、SYNC_WRITE 一帧刷 8 舵机、REG_WRITE+ACTION、广播写 |
| 故障注入 | 掉线静默、堵转 `ERR_OVERLOAD`、过温 `ERR_OVERHEAT`+闭锁、力矩关闭不动 |

## 验证方式

```bash
python host/tests/smoke_test_control.py   # 25/25 passed
# 或：pytest host/tests/smoke_test_control.py
```

首轮 20/25，暴露并修复 3 处缺陷：①PING 未校验舵机存在性/掉线；②全速分支 `int(inf)` 溢出；③`speed_raw` 类型污染寄存器视图。

## 已知限制（诚实声明）

1. **寄存器地址待实机校验**：`Reg` 表按 SCS 系列公开资料 + 上游行为填写，全部标注 `TODO(实机校验)`；上板后用 FD 调试工具核对，修订只改 `Reg` 一处（对应 interface.md 待定项 1/2）
2. **`scs_sim` 物理常数非真值**：速度/温度/负载演化系数标注 SIM ONLY，仅用于行为演示与测试
3. **广播 PING 模拟为不响应**：真实总线会碰撞；项目主链路不使用广播 PING
4. **Load 寄存器仅存幅值**：真实寄存器 bit10 为方向位，实机校验时统一处理

## RTL 对照计划（下游）

- `fpga/rtl/scs_protocol.sv`：组包/解包/校验和与本模型逐字节比对
- `fpga/sim/scs_slave_model.sv`：复现 `transact` + `step` 行为（含故障注入）
- `tb_servo_bus.sv`：以本 PR 测试用例的同帧序列为激励

## 评审要点

1. 帧格式 LENGTH/CHECKSUM 定义是否与你手头 Feetech SCS 手册一致（唯一的协议权威分歧点）
2. `Reg` 地址：重点 0x28(Torque)/0x2A(GoalPos)/0x2E(Speed)/0x3A~0x41(反馈区)
3. 故障注入行为是否覆盖 `grasp_fsm` TB 的保护场景预期
4. `scs_sim` 接口形状（帧进帧出 + 显式时间）是否满足未来 DPU/硬件在环的扩展
