# PS↔PL 接口契约 v0.2

> 本文件是 `host/` 与 `fpga/` 并行开发的唯一依据。
> 变更规则：任何字段增删必须当日记入 `docs/log/`，并在此提升版本号。
>
> **v0.1 → v0.2 变更**（2026-09-30）：
> - 待定项 3 定稿：**单总线拓扑**（见 §2.1）
> - 新增 §2 物理层与引脚分配（Z19 实测引脚、电平转换约束）
> - 新增 §6 单总线时隙调度（1kHz 预算表）
> - 寄存器映射（§3）与中断（§4）**不变**，v0.1 的 host/fpga 开发不受影响

## 1. 总体

- 通道：AXI4-Lite 从接口，32 位数据，基地址由 Vivado 地址编辑器分配（`0x4000_0000` 起，默认）。
- PL 侧模块 `axi_lite_regs.sv` 实现，host 侧 `backend_fpga.py` 使用 `/dev/mem` mmap 访问。
- PL 时钟：板上差分 200MHz `PL_CLK0`（H24/G25）→ MMCM → 100MHz `ctrl_clk`（控制环）+ 200MHz（总线位定时过采样）。寄存器侧自动 CDC。

## 2. 物理层与引脚分配（v0.2 新增）

### 2.1 舵机总线拓扑（待定项 3 定稿）

- **单总线**：1 条半双工 TTL 总线串联 8 × SCS0009（ID 1~8），1Mbps，与官方装配指南接线一致（官方 `PythonExample` 即单串口 `baudrate=1000000` 驱动 8 舵机）。
- 舵机 ID ↔ 手指映射（官方 Demo 默认）：ID 1/2=食指、3/4=中指、5/6=无名指、7/8=拇指；每指两舵机 = 屈曲 + 外展。
- 带宽预算与调度见 §6，1kHz 下发 + 轮询回读可行。
- 升级路径：若实测回读带宽不足，FMC1 LA03~LA09 空闲可扩第二总线，RTL 按参数化通道数设计。

### 2.2 电平转换（硬约束，必须）

- Z19 全部 PL IO 位于 HP bank（FMC1=BANK67/68，FMC2=BANK64/65/66），**最高 1.8V**（FMC1 由跳帽 J5 选 1.8V/1.2V，**必须置 1.8V**）。
- SCS0009 为 5V TTL 逻辑 → 直连会烧毁 bank，必须经双向电平转换。
- **选定方案**：TXS0108E 8 通道双向电平转换模块（VCCA 1.2~3.6V，VCCB 1.65~5.5V，自动方向感应，推挽 ≥24Mbps）：
  - A 侧接 FMC1 `VADJ`（1.8V）与 `LA02_P`；
  - B 侧接舵机总线 DATA 与舵机 5V；
  - 自动方向感应 → **无需 DIR 信号**，半双工换向延迟 ns 级（位周期 1µs），无冲突；
  - 仅用 1 通道，其余 7 通道留作升级。
- 转接板采购组合（无现成单板方案）：
  1. FMC1 HPC → 2.54mm 排针裸转接板（引出 LA + VADJ + GND）；
  2. TXS0108E 模块（¥6.6，淘宝/1688）。
- 舵机供电：**外置 5V/2A 电源**（官方 BOM：DC 适配器），严禁从 VADJ/FMC 取电。

### 2.3 PL 引脚分配（引脚号实测自《Z19 用户手册》）

| 信号 | 物理位置 | ZU19EG 引脚 | 方向 | 电平 | 用途 |
|---|---|---|---|---|---|
| `SERVO_DATA` | FMC1 LA02_P | L17 | inout | LVCMOS18 | 舵机总线数据（经 TXS0108E） |
| `SERVO_DATA_SPARE` | FMC1 LA02_N | K17 | inout | LVCMOS18 | 预留第二总线 |
| `PL_CLK0_P` / `PL_CLK0_N` | 板载晶振 | H24 / G25 | in | 差分 | 200MHz 系统时钟 → MMCM |
| `HEARTBEAT` | 板载 PL_LED1 | B3 | out | — | 1Hz 心跳 |
| `ESTOP_N` | 板载 PL_KEY | D4 | in | — | 急停按键（低有效，直连 grasp_fsm 保护逻辑） |

- xdc 电平约束：FMC 引脚 LVCMOS18；`ESTOP_N` 需内部上拉 + 消抖（RTL 内实现）。
- 板载 PL_UART（C3/C6，经 CP2102 接 PC）保留为调试通道（tx_eeprom 类辅助），不接舵机。

## 3. 寄存器映射（偏移 = 基地址 + offset，v0.1 不变）

### 控制区（host → PL）

| 偏移 | 名称 | 字段 | 说明 |
|---|---|---|---|
| 0x00 | CTRL | [0] enable, [1] mode(0:直接角度/1:状态机), [2] estop | 使能与急停 |
| 0x04 | CMD | [7:0] cmd, [15:8] arg | 0x01=启动抓取 0x02=释放 0x03=预张 0x04=力矩使能(arg 1/0) 0x10=回中 |
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

## 4. 中断（v0.1 不变）

- PL → PS 一根中断（AXI INTC）：触发条件 = FSM 状态跳变 或 ERR_BITMAP 非零。
- host 侧收到中断后读 STATUS/ERR_BITMAP，驱动 UI 与日志。

## 5. 软件环后端（backend_serial.py，对比基准）

- 通道：USB-TTL（Waveshare 总线驱动板，PS USB3.0 口，`/dev/ttyUSB0`），1Mbps 半双工。
- 协议：Feetech SCS 官方协议，指令与 §6 时隙内容一一对应（保证两个后端行为可比）。
- 轮询：Python 循环 + `time.perf_counter()` 打点，记录环周期直方图 → `data/metrics/`。

## 6. 单总线时隙调度（v0.2 新增）

1kHz 控制周期（1ms）内的总线事务预算 @1Mbps（10bit/字节）。
帧长推导以 `host/app/control/scs_protocol.py`（golden model）实现为权威：

| 时隙 | 事务 | 帧长 | 耗时 |
|---|---|---|---|
| t0 | SYNC_WRITE(0x83) 一次下发 8 舵机 **目标位置（per=2）** | 32B | ≈320µs |
| t1 | READ 舵机 #i 连读 0x3A~0x41（pos/speed/load/volt/temp 共 8B） | 7B 请求 + 13B 响应 | ≈250µs 含换向 |
| t2 | READ 舵机 #j（同上） | 同上 | ≈250µs |
| 合计 | | | **≈820µs** ✓（余量 180µs） |

- **v0.2.1 修正**：速度（0x2E）不再进周期时隙——CLOSING 期间速度恒定，
  改为**事件事务**（状态迁移时由 PL 在时隙空闲段插入广播/单播 WRITE），
  每 8 舵机 6B 连写视图（位置+Goal_Time+速度）需 64B=640µs，超时隙预算。
- 推导：SYNC_WRITE per=2：params = addr(1)+len(1)+8×(id 1+data 2)=18B，LEN=20，帧总长 24B？
  按 `build_sync_write` 实测 = **32B**（含广播 ID 与校验）；READ 响应 LEN = err(1)+8+cs(1)=10 → 13B。
  事件事务（空闲段）：WRITE 广播力矩开关 8B；速度单播×8 ≈128µs。

- 回读调度：i、j 轮转扫过 8 个 ID → **每舵机回读 250Hz**，下发 1kHz。
- 闭合阶段（FSM_STATE=CLOSING）可切换为"关键舵机模式"：只轮询负载监视通道（默认 4 个），回读提至 500Hz。
- 回读超时 100µs 无响应 → ERR_BITMAP 对应位置位（掉线判定）。
- 该调度由 `servo_bus_ctrl.sv` 在 `ctrl_clk` 域以计数器硬实现，宿主机无法干扰时序。

## 7. 待定项

- [ ] 待定项 1：角度 0.1° 定点格式与舵机原始行程换算表（格式已定：[11:0] 无符号 0.1°；SCS0009 原始 0~4095 ↔ 物理角度换算真值待 `tools/calibrate_servo.py` 实测）
- [ ] 待定项 2：力矩 4 位等级 ↔ SCS Torque/Load 寄存器写入值映射（真值待实测标定）
- [x] ~~待定项 3：8 路拓扑~~ → **单总线**（v0.2 定稿，见 §2.1/§6）
- [ ] 待定项 4（新增）：左右手确认（官方 Demo `Side` 变量：右手=1 / 左手=2；影响外展舵机角度符号与引导逻辑，装配实物确认后定稿）
