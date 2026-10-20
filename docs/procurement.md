# 硬件与采购（现行，2026-10-20）

> **此页取代旧八舵机采购计划。** 原需购买 5V 舵机电源、FMC 转接板、TXS0108E 电平转换和剪 USB 线取电的建议已**废止**；请勿用于当前 RoArm-M2-S 系统。旧版可通过 Git 历史追溯，不删历史证据。

> **本期第一版接线顺序改为 USB 摄像头→PC、RoArm USB→PC；Z19/FPGA 稍后并行接入，不再是实体抓放前置**。原下方“Z19 PS USB Host”拓扑仅是后续扩展候选，PC+RoArm 的实体主线应先实测。详见 [Demo-first 决策](relaunch_20261020/DEMO_FIRST_POLICY.md)。

## 本期设备

| 设备 | 事实状态 | 用途 / 待验证项 |
|---|---|---|
| ALINX Z19 XCZU19EG | 已有 | Linux/SSH 与旧 MJC1 R2 实板有历史证据；新串口+UVC+FPGA 并发未验证 |
| Waveshare RoArm-M2-S 标准整机 | **用户已下单** | 自带 ESP32、夹爪、底座固定件和独立电源；**到货、固件、动作和反馈尚未验收** |
| RoArm 原厂 12V 5A 电源 | 官方标准套装应包含 | 实际开箱核对铭牌与极性；机械臂不可从 Z19 USB 取舵机电源 |
| RoArm USB-A↔Type-C 线 | 官方标准套装应包含 | 用于 PS Linux USB Host 串口通信；线材和驱动到货后实测 |
| 实验室 USB 摄像头 | 用户称可用、曾接树莓派 | 优先借用固定俯视；型号、UVC 与 Z19 内核配置未验证 |
| Windows PC、Vivado/Vitis 2020.1 | 已有 | 离线开发、仿真、PC取图保底；不以安装 2020.2/ROS2 为任务前置 |
| USB 麦克风 | 具体到货状态待确认 | #12 可选，不能阻塞实物抓放 |

**暂不采购：** FMC-HPC 转接、电平转换、SCS0009 散舵机、5V 6A 八舵机电源、另一台摄像头、另一块 FPGA、额外 ESP32 或新的 ROS2 主机。原设备损坏或不能适配时先保留实验日志，再由负责人审批补购。

## 需要额外准备的低成本物料

- 摄像头 USB **数据**线（如实验室相机未自带）；机械臂和摄像头各占独立接口/线材。
- 固定俯视摄像头的支架，首先借用实验室支架；避免把相机放在移动机械臂上形成动态手眼标定问题。
- 轻质、高对比颜色方块/纸盒、桌面标定纸或棋盘格、直尺和固定投放区。
- 稳定桌面以及**现场人员随时可触及的独立机械臂 12V 断能方式**，需先检查断电时机械臂失力下垂风险。

## 当前方案连线（**方案图，不是已接通事实**）

```text
固定 USB 相机 ─ USB ─> Z19 PS USB Host（若驱动阻断则 PC 采集）
RoArm ESP32 ─ USB 串口 ─> Z19 PS USB Host（115200/串口由现场确认）
Z19 PS ─ AXI 寄存器 ─> Z19 PL 动作授权 / 超时 / STOP
RoArm 舵机 ─ 厂商原配独立 12V 5A 供电（不取自 Z19）
```

注意：Z19 PL **不通过 FMC 直接控制 RoArm 舵机总线**。ESP32 执行厂家位置/逆运动学控制，Z19 通过 PS 串口间接执行经过 PL 授权的动作。软件 STOP 不等于实体立即停机；详见 [硬件操作和安全](relaunch_20261020/HARDWARE_BRINGUP.md)。

## 开箱和兼容性核对

厂商资料：[产品](https://www.waveshare.net/shop/RoArm-M2-S.htm)、[官方 Python SDK](https://github.com/waveshareteam/waveshare_roarm_sdk)、[固件](https://github.com/waveshareteam/roarm_m2)。实际下单的 S 整机应当是组装好、带夹爪、电源与通信线的套装，但淘宝商品具体发货由现场实收清点判定。官方开源 commit/API/许可证记录见 [RoArm 核查](relaunch_20261020/ROARM_OPEN_SOURCE_AUDIT.md)。

设备到货后由 Citlali6 安装、固定和批准首次上电。先 Web UI 和 PC 串口低速动作/反馈，再 Z19 串口；任何让机械臂运动、刷固件、替换内核或加载 PL 的操作必须当次获授权。计划参见 [十天排期](relaunch_20261020/TEN_DAY_EXECUTION.md)。
