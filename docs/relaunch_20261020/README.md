# AmazingHand-Z19｜十天工程交付入口（2026-10-20）

> **当前唯一优先级：真实、完整、稳定、好展示的视觉抓放效果**。用户已明确：FPGA 不是实体抓放的前置条件，任何 PL/驱动/构建难题不允许拖垮已经能正常运行的 PC→RoArm 系统。先读 [Demo-first 决策与任务图](DEMO_FIRST_POLICY.md)，本页所述均为任务目标，**非实物已验收声明**。

## 1. 一句话项目简介

采用已下单的微雪 **RoArm-M2-S**（原厂 ESP32+舵机+夹爪）和实验室已有 USB 摄像头，通过 **PC Python/OpenCV + 微雪官方 SDK** 完成实时目标检测、桌面标定、真实抓取、搬运投放、反馈显示和互动演示。ALINX Z19 的 ARM PS/FPGA PL 作为**独立并行的实测硬件扩展**尽量利用现有成果，避免十天内从零重构整套控制固件。

教育、机器人嵌入式、固定桌面轻量分拣是主要用途；不宣称医疗级、工业安全级、任意目标识别或自制舵机力控。

## 2. 分级验收，任何一级都不能冒充下一级

| 阶段 | 展示内容 | 核心证据 |
|---|---|---|
| R0 原厂真机 | PC 官方 SDK 查询真实反馈、低速关节与夹爪动作 | 实机日志/视频、设备与固件版本 |
| R1 固定点抓放 | PC 受限动作，实际轻质方块完整夹取/移动/投放 | 每阶段反馈、视频、失败记录 |
| **R2 视觉智能抓放（必须优先）** | USB 相机新帧、识别/标定、目标改变位置后仍能抓放、完整 UI | 三位置真机测试、实际任务记录 |
| R3 Z19/PL（并行争取） | 复用原 PS↔PL 资产或最小独立逻辑，**真实 PL** 计时/反馈/状态展示 | 匹配的 bit/hash、寄存器/日志、真实板端测试 |
| R4 可选 | 中文语音、NCNN、ROS2、多物体 | 不阻塞 R2 |

**不能称 R2 是“已经接入 FPGA 的机械臂”，也不能仅因为开发板上电或 PS 跑 Linux 就宣称完成 R3。** 竞赛 FPGA 类别的实际提交条件由队长依官方通知核对，不能伪造参赛符合性。

## 3. 技术路径与现有成果

```text
USB摄像头 → PC OpenCV目标框/位置/标定 → PC 安全任务状态机/界面
                                                ↓
                                      微雪 Python SDK/USB
                                                ↓
                                      RoArm ESP32→实物夹爪
                                              ↕真实反馈

   Z19 PS/PL 是并行路径：已有 MJC1 R2 实板 HIL 验证；
   先独立展示可复用的真实 FPGA 参与，不串入以上运行前提。
```

旧 IMX214 camera-only 在 Linux 上确实有 1080p 和约 25fps PC 接收的验收，但与 MJC1 R2 控制 profile 不可直接叠加，未签收的 MIPI+HIL 组合固件 **NOT DEPLOYABLE**。实验室 USB 摄像头是 PC 主线的快速独立视觉输入，不表示原 MIPI 工作作废；当期不优先在 Z19 修新 UVC 驱动。

**微雪源码状态**：官方 ESP32 固件、Python SDK、ROS2 工程**公开可查**；当前本仓库仅有版本/API/许可证审计，**尚未完整备份源码**。由 [#14](https://github.com/Citlali6/AmazingHand-Z19/issues/14) 将最小 PC 运行依赖锁版本并形成可重复环境，源码快照的许可证与第三方归属需审计。参见 [厂商开源资料](ROARM_OPEN_SOURCE_AUDIT.md)。

## 4. 执行顺序与已有任务

1. [#14 官方代码/SDK版本/PC环境](https://github.com/Citlali6/AmazingHand-Z19/issues/14) 与 [#7 实体机械臂 SDK](https://github.com/Citlali6/AmazingHand-Z19/issues/7) → R0/R1；
2. [#8 PC USB 相机、色块检测与标定](https://github.com/Citlali6/AmazingHand-Z19/issues/8) 与上面并行；
3. [#10 真视觉变位抓放、UI](https://github.com/Citlali6/AmazingHand-Z19/issues/10) → R2，**不依赖 #9**；
4. [#11 现场安全、失败统计、视频与复现](https://github.com/Citlali6/AmazingHand-Z19/issues/11)；
5. [#9 Z19 FPGA 合理复用](https://github.com/Citlali6/AmazingHand-Z19/issues/9) 单独 P1 并行；[#12 离线语音](https://github.com/Citlali6/AmazingHand-Z19/issues/12) HOLD。

## 5. 必读技术文档

- [当前最权威决策](DEMO_FIRST_POLICY.md) · [架构](SYSTEM_ARCHITECTURE.md) · [十天排期](TEN_DAY_EXECUTION.md)
- [微雪固件与 SDK 真实源码核查](ROARM_OPEN_SOURCE_AUDIT.md)
- [PC 先行的真实设备上手与安全](HARDWARE_BRINGUP.md)
- [两位队友与 Codex 工作说明](TEAM_ONBOARDING.md)
- [旧方案隔离与证据级别](DOC_STATUS_AND_RULES.md)
- [仓库 Git 约束](../GIT_WORKFLOW.md) · [Codex 规则](../../AGENTS.md) · [总控 Issue #6](https://github.com/Citlali6/AmazingHand-Z19/issues/6)

## 6. 安全与当前状态

RoArm-M2-S 已下单，尚未到货验收；实验室 USB 相机曾在树莓派上使用，未必已在 PC/Z19 实测。默认离线 Mock/dry-run。只有 Citlali6 在现场确认独立 12V、电源/底座/可用范围且批准后，才允许真实低速运动。ESP32 固件启动可能包含回初始位姿动作，软件 STOP/关扭矩不能替代人工独立电源断能。所有失败及未验证状态须明确保留。
