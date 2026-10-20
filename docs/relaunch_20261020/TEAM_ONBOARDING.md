# FPGA辅助视觉抓取系统｜队友与 Codex 必读

> **最新决策 2026-10-20**：项目主线是 PC + USB 相机 + RoArm-M2-S 的实际视觉抓放。先完成 R0/R1/R2，**不需要等 Z19 PL 状态机开发完成才能进行真实机械臂或视觉联调**。详情 [Demo-first 决策](DEMO_FIRST_POLICY.md)。

## 1. 新队员 5 分钟理解项目

固定俯视实验室 USB 摄像头在电脑 OpenCV 中检测彩色小方块、转换成桌面/机械臂坐标，PC 运行一个有机械工作域保护的任务程序，通过微雪官方 Python SDK/USB 串口给 RoArm-M2-S 的原厂 ESP32 发送安全运动命令，机械臂真实抓取、搬运、投放。展示实时画面、目标框、反馈、阶段、异常和实验数据。

Z19 XCZU19EG 是比赛 FPGA 相关的**并行扩展**：先复用原 MJC1 R2、IMX214 等板端硬件积累，设计和验证有实际效果的简单 PL 功能。若 FPGA 集成未成，PC 视觉真机演示仍按期保留；但不得将 PC-only 演示谎报成 FPGA 实物控制。

## 2. 人员分工和仓库任务

| 角色 | 任务 | 起始动作 |
|---|---|---|
| Citlali6（负责人） | 接线/上电/唯一硬件许可、工作时段、演示决策和 PR 合并 | 确认设备到货、工位和安全断能 |
| 队友 A：视觉/UI | USB 摄像头 PC 取图、HSV 识别、固定平面标定、界面与三点位对照 | [#8](https://github.com/Citlali6/VisionGrasp-Z19/issues/8)，不等 FPGA |
| 队友 B：机械臂/SDK | 官方固件与 SDK、PC 依赖、关节反馈/夹爪/动作编排、限制运动范围 | [#14](https://github.com/Citlali6/VisionGrasp-Z19/issues/14) + [#7](https://github.com/Citlali6/VisionGrasp-Z19/issues/7)，不等 FPGA |
| 双方联调 | 固定点 R1 → 三位置 R2 → UI/日志 → 安全测试 | [#10](https://github.com/Citlali6/VisionGrasp-Z19/issues/10) / [#11](https://github.com/Citlali6/VisionGrasp-Z19/issues/11) |
| FPGA 支线（可单独 Codex） | #9 先审计、选最小独立 PL 真机展示，低成本复用，不能干扰 PC | [#9](https://github.com/Citlali6/VisionGrasp-Z19/issues/9)，P1 非阻断 |
| 语音 | #12 HOLD，等 R2 稳定再考虑 | [#12](https://github.com/Citlali6/VisionGrasp-Z19/issues/12) |

由于没有两位队友 GitHub 账号，不擅自给真人分配 assignee。先到[总控 #6](https://github.com/Citlali6/VisionGrasp-Z19/issues/6) 自报工作角色和可到场时段。

## 3. Codex 可用什么，不应重写什么

- **用官方开源**：ESP32 固件 [roarm_m2](https://github.com/waveshareteam/roarm_m2)，Python SDK [waveshare_roarm_sdk](https://github.com/waveshareteam/waveshare_roarm_sdk)；现行仓库只有厂商源码版本和 API 审计，未完整 vendoring。#14 负责固定依赖与合法引用。
- **不造轮子**：机械臂舵机驱动、IK、ROS2、重新设计手指结构都不是 10 天 MVP；只写安全 PC 控制适配、感知和展示。
- **不要把历史目录当新源码**：老 `SCS0009`、FMC/1.8V、MJC1/ AHIL 的原协议对应旧项目设备；不能用它给 RoArm 下发真实串口包。原相机 profile 与 MJC1-only 也不能同时加载。
- 视觉先 PC、模型先 HSV 高对比色块；只有实际显示了移动后不同的真实抓取目标才称 R2。

## 4. 代码工作流

每次运行 Codex 必须先读 `AGENTS.md`、`docs/GIT_WORKFLOW.md`、本目录的 [Demo-first 决策](DEMO_FIRST_POLICY.md) 与对应 Issue。唯一允许写入的 GitHub 仓库是 `Citlali6/VisionGrasp-Z19`；旧 Tom 仓库永久只读。**最新 main→独立分支→小范围变更→实际测试→PR→授权人审核决定合并**。Codex 对应 Issue 必须由负责人当轮明确启动，Issue 文本不自动授权独立操作。

所有脚本默认 `dry-run`；没得到当次现场许可时，不得上电、刷 ESP32、执行关节运动、重配 PL、改内核/SD、安装高风险全局依赖。独立访问信号数据，不能擅自替其他队友 Review 或合并。

## 5. 审核和证据用语

`PLAN` = 设计，`CODED` = 已写，`PC TESTED` = PC 实测，`SIM TESTED` = 模拟，`ROARM TESTED` = 真机械臂控制/反馈，`R1 TESTED` = 实物固定点抓放，`R2 E2E TESTED` = 真相机实时视觉、变位抓放和 UI，`Z19/PL TESTED` = FPGA 实板证据。绝不将一个等级冒充另一个。

PR 至少提供：源 commit/hash、具体操作、依赖安装和运行说明、自动化测试与退出码、实际视频/串口反馈（如有）、失败/风险、可回退路径和下一步现场待执行事项。**物理停止、串口 ACK、成功夹取分开验证**；不得为了快而取消工作空间限制与人工断能。

## 6. 向队友发送的确认格式

```text
已阅读 main README、DEMO_FIRST_POLICY、TEAM_ONBOARDING 和 Issue #6。
GitHub 用户名：
认领队员 A / B（或仅 #9 FPGA 支线）：
D1-D10 每天可投入时间：
是否可以到场调机：
最先准备的 PC 结果（真实/Mock）：
需要 Citlali6 帮忙的硬件/信息：
承诺不在无现场批准下发送运动指令、刷固件、重配PL或合并他人任务。
```
