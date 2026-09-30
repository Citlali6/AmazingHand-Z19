# PS↔PL 接口契约 v0.1（草案）

> 本文件是 `host/` 与 `fpga/` 并行开发的唯一依据。
> 变更规则：任何字段增删必须当日记入 `docs/log/`，并在此提升版本号。

## 1. 总体

- 通道：AXI4-Lite 从接口，32 位数据，基地址由 Vivado 地址编辑器分配（`0x4000_0000` 起，默认）。
- PL 侧模块 `axi_lite_regs.sv` 实现，host 侧 `backend_fpga.py` 使用 `/dev/mem` mmap 访问。
- PL 时钟：总线控制环运行于独立时钟域（目标 100MHz），寄存器侧自动 CDC。

## 2. 寄存器映射（偏移 = 基地址 + offset）

### 控制区（host → PL）

| 偏移 | 名称 | 字段 | 说明 |
|---|---|---|---|
| 0x00 | CTRL | [0] enable, [1] mode(0:直接角度/1:状态机), [2] estop | 使能与急停 |
| 0x04 | CMD | [7:0] cmd, [15:8] arg | 0x01=启动抓取 0x02=释放 0x03=预张 0x10=回中 |
| 0x10+i*4 (i=0..7) | TARGET_i | [11:0] 角度(0.1°单位), [15:12] 舵机ID | 各舵机目标角 |
| 0x30 | TORQUE_LIM | 每 4 位一个通道，0~15 级 | 力矩上限（对应 SCS Load 限幅） |
| 0x34 | TIMING | [7:0] 闭合速度, [15:8] 轮询周期(×0.1ms) | 1kHz 默认 |

### 状态区（PL → host）

| 偏移 | 名称 | 字段 | 说明 |
|---|---|---|---|
| 0x80 | STATUS | [0] fsm_busy, [1] grasped, [2] timeout, [3] fault | 主状态字 |
| 0x84 | FSM_STATE | [7:0] 状态编码 | IDLE/PREGRASP/CLOSING/HOLD/RELEASING/PROTECT |
| 0x90+i*4 (i=0..7) | MEAS_i | [11:0] 角度, [15:12] 标志 | 最近一次回读位置 |
| 0xB0 | LOAD_i | 0xB0+i*2，16 位半字 ×8 | 回读力矩（SCS Load 原始值） |
| 0xD0 | TEMP | [7:0] 最高温度通道, [15:8] 温度值 | 过温监视 |
| 0xE0 | ERR_BITMAP | 每位一通道 | 堵转/掉线/超温位图 |
| 0xF0 | TIMESTAMP | 32 位循环计数 | 供 host 测环周期抖动（对比实验用） |

## 3. 中断

- PL → PS 一根中断（AXI INTC）：触发条件 = FSM 状态跳变 或 ERR_BITMAP 非零。
- host 侧收到中断后读 STATUS/ERR_BITMAP，驱动 UI 与日志。

## 4. 软件环后端（backend_serial.py，对比基准）

- 通道：USB-TTL（Waveshare 总线驱动板），115200/1M 波特率半双工。
- 协议：Feetech SCS 官方协议，指令与 2 节字段一一对应（保证两个后端行为可比）。
- 轮询：Python 循环 + `time.perf_counter()` 打点，记录环周期直方图 → `data/metrics/`。

## 5. 待定项（RTL 设计前定稿）

- [ ] 角度 0.1° 定点格式与舵机原始行程的换算表（依赖舵机校准结果）
- [ ] 力矩 4 位等级与 SCS Torque/Load 寄存器写入值的映射（依赖实测标定）
- [ ] 8 路是物理 8 条 UART 还是 1 条总线轮询 8 ID（取决于接线方案，组装已定则按实物定）
