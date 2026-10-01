# PR — Host 应用骨架：三后端抽象 + 主状态机 + 抓取策略

> **复制本文件内容到 GitHub PR 描述框即可创建 PR**（base：`main`）
> 分支：`feat/host-skeleton` · 前置：PR #2（SCS 协议 golden model）已合并
> 状态：Draft（可评审）

---

## 概述

无硬件阶段第 2 步交付：控制层"后端抽象"全量落地——**sim / serial / fpga 三后端实现同一接口**，换硬件只改 `settings.yaml` 一行；主状态机（待命→识别→引导→抓取→保持→释放）全链路可在 PC 上用 mock 输入空转；抓取策略查表骨架就位。本 PR 同时包含对 PR #2 的复查修复（含一个影响 RTL 设计的协议布局 bug）。

## 提交清单

| Commit | 内容 |
|---|---|
| `2a6579a` | feat(host): 三后端抽象+主状态机+策略查表；复查修复半帧崩溃与 SYNC_WRITE 布局 bug（37 测试全过） |
| `53369e1` | docs: 恢复 PR #001 文档 |
| `60eb13b` | merge: origin/main 并入（消除 squash 假冲突） |

## 新增文件

```
host/app/control/servo_base.py      # ServoBackend 抽象基类 + GraspPlan/ServoFeedback/FsmSnapshot 契约
host/app/control/backend_sim.py     # 模拟后端（虚拟总线包装 + 软件版 grasp_fsm）
host/app/control/backend_serial.py  # USB-TTL 软件环后端（F5 对比基准，pyserial 延迟导入）
host/app/control/backend_fpga.py    # AXI4-Lite 后端（/dev/mem mmap，偏移对照 interface.md v0.2）
host/app/strategy/grasp_selector.py # (类别,尺寸) → GraspPlan 查表选择器
host/app/strategy/grasp_table.json  # 抓取参数表骨架（banana/apple/bottle，source 字段溯源）
host/app/main.py                    # 七态主状态机 + Mock 语音/视觉 + 后端工厂 + CLI
host/config/settings.yaml           # 配置（数据与代码分离）
host/tests/smoke_test_backend.py    # 第 2 步冒烟测试（10 用例）
```

修改：`scs_sim.py`（半帧安全 + 广播 RESET + GOAL_TIME 寄存器）、`smoke_test_control.py`（27 用例）、`interface.md`（CMD 扩展 0x04）、`architecture.md`（文件树同步）。

## 设计要点

### 1. 三后端统一契约（`servo_base.py`）

```
ServoBackend: open/close/set_torque/set_targets/start_grasp_fsm/release/poll_fsm/
              emergency_stop/read_loop_timestamp/tick
```

- `GraspPlan` 是三后端**共同输入契约**——对比实验（F5）的变量控制基础：同一份计划，差异只来自控制环本身
- `read_loop_timestamp()`：sim=虚拟时钟 µs / serial=`perf_counter_ns` / fpga=TIMESTAMP 寄存器，供 P99 抖动统计
- `tick(dt)` 钩子：仅 sim 有确定性动力学，serial/fpga 为空——同一 `run()` 主循环跑三个后端

### 2. 软件版 grasp_fsm（`backend_sim.py`，RTL 行为 golden model #2）

PREGRASP→CLOSING→HOLD→RELEASING→PROTECT 状态迁移与判定条件（力矩阈值/到位/超时/故障）与未来 RTL `grasp_fsm.sv` 一一对应；`tb_grasp_fsm.sv` 将以同一 GraspPlan + 同一故障注入序列比对状态轨迹。

### 3. AXI 后端（`backend_fpga.py`）

寄存器偏移严格对照 interface.md v0.2；LOAD 区 16 位半字跨 32 位字对齐读取；**只做"写下发、读回读"，不参与实时调度**——控制环时序完全由 PL 硬件保证，这是对比实验的变量控制。

### 4. 主状态机（`main.py`）

- 依赖注入（`Deps`）：voice/vision 走 Protocol 抽象，Mock 实现（脚本命令 + 延迟就位）在正式模块（kws.py/detector.py）落地后整体替换，状态机零改动
- `run()` 显式 tick 驱动、返回状态历史——冒烟测试直接断言状态序列
- FAULT→reset 人工恢复路径；识别/引导超时回 IDLE

## 复查与修复记录（本轮测试驱动的 4 项）

| # | 发现 | 修复 | 影响 |
|---|---|---|---|
| 1 | `transact(b'\xff\xff')` 抛 IndexError（半帧） | <5 字节安全丢弃 | UART 常态输入；RTL 从机行为参照 |
| 2 | REG_WRITE 测试断言无效（写入值=默认值） | 改用非默认值严格验证 | ACTION 语义可信 |
| 3 | 广播 RESET 缺失 | 补全（全舵机出厂态） | 急停兜底路径 |
| 4 | **SYNC_WRITE 数据布局 bug**：0x2A 起连写 4B 实际落在"位置+Goal_Time(0x2C)"，速度(0x2E)从未写入 → 限速失效、舵机全速冲刺 | 改为协议正确 6B 连写：位置(2B)+Goal_Time=0(2B)+速度(2B)；sim 补 GOAL_TIME 解析 | **RTL SYNC_WRITE 解析必须支持 6B 连写视图**；单测覆盖不到组合路径，集成测试立功 |

契约变更：interface.md CMD 表扩展 `0x04=力矩使能(arg 1/0)`（实现 fpga 后端时发现契约空白，正式入契约）；`GraspPlan` 补 `pregrasp_deg` 预张角字段。

## 验证方式

```bash
python host/tests/smoke_test_control.py   # 27/27 passed（协议层回归）
python host/tests/smoke_test_backend.py   # 10/10 passed（本 PR 新增）
python host/app/main.py --mock-voice "抓起香蕉,放下"
# → IDLE → RECOGNIZING → GUIDING → GRASPING → HOLDING → RELEASING → IDLE
```

CLI 验收注意：无物体负载时 HOLDING 报 `closing timeout (held at obstacle)` 而非 grasped——超时保持与力控抓稳语义已分离（`test_fsm_closing_timeout_semantics` 专门守护）。

## 已知限制

1. `backend_serial`/`backend_fpga` 未上板验证（无硬件）；串口收发与 mmap 代码按契约与 Linux 惯例实现，板端联调时修
2. `grasp_table.json` 全部 `source=default` 占位——待 `sim/verify_grasp.py`（第 3 步）与实机标定填充
3. 力矩等级→负载阈值映射（`TORQUE_LEVEL_STEP=64`）与角度→raw 换算为占位，对应 interface.md 待定项 1/2
4. 语音/视觉仍为 Mock（`--mock-voice`），正式链路在第 4 步接入
5. Windows 上 `backend_fpga.open()` 会报错（/dev/mem 不存在）——设计如此，PC 冒烟走 sim

## 评审要点

1. `ServoBackend` 接口是否满足 F5 对比实验需求（缺什么接口现在提，上板后改契约成本翻倍）
2. 软件版 grasp_fsm 的迁移条件（`MIN_CLOSING_S`/`CLOSING_TIMEOUT_S`/力阈值判定）是否与你的力控预期一致——RTL 实现前这是最后修改窗口
3. `backend_fpga` 寄存器访问与 interface.md v0.2 逐项核对（尤其 LOAD 半字对齐与 TARGET 编码——编码细则=待定项 1，当前占位）
4. `grasp_table.json` 的 15 类物品清单与角度语义（相对中位偏移）确认
