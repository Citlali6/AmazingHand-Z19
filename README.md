# FPGA辅助视觉抓取系统

**唯一开发仓库：[Citlali6/VisionGrasp-Z19](https://github.com/Citlali6/VisionGrasp-Z19)** · 项目负责人 Citlali6 · 默认分支 `main`

> **名称说明：** 当前作品正式展示名为「FPGA辅助视觉抓取系统」，新 GitHub 仓库名为 `VisionGrasp-Z19`；`AmazingHand-Z19` 是原仓库名，`AmazingHand/` 是旧灵巧手的历史代码目录。历史源代码、作者署名与实验记录仍予保留。

> **2026-10-20 用户最终决定：演示效果、工程完整度和稳定性是最高优先级。** 先用微雪 **RoArm-M2-S + 原厂 ESP32/Python SDK + 实验室 USB 摄像头 + PC** 做出真实、可重复的抓取分拣作品；**Z19/FPGA 是并行的真实技术加分项，绝不作为机械臂运动、视觉抓取或演示 UI 的前置条件**。项目如需满足比赛关于 FPGA 的正式要求，最终须单独提供有真实证据的 PL 功能，不能仅放置板卡或让 PS 跑 Linux 就称 FPGA 已用。

**Windows Anaconda 已确认：[Conda 环境安装与摄像头自检](docs/development/ANACONDA_SETUP_WINDOWS.md)**

**开发已启动（机械臂到货前）：[Codex 第一波任务令](docs/development/PRE_ARRIVAL_EXECUTION.md) · [PC 共享接口契约](docs/development/PC_MVP_CONTRACT.md) · [#14 SDK](https://github.com/Citlali6/VisionGrasp-Z19/issues/14) · [#7 RoArm Fake](https://github.com/Citlali6/VisionGrasp-Z19/issues/7) · [#8 USB 视觉](https://github.com/Citlali6/VisionGrasp-Z19/issues/8) · [#18 Mock 集成](https://github.com/Citlali6/VisionGrasp-Z19/issues/18)**

**第一站：[Demo-first 决策与任务依赖](docs/relaunch_20261020/DEMO_FIRST_POLICY.md)** · [更名后 Git/Codex 迁移步骤](docs/relaunch_20261020/REPOSITORY_RENAME.md) · [文档导航](docs/README.md) · [团队总控 #6](https://github.com/Citlali6/VisionGrasp-Z19/issues/6)

## 我们做什么？

在固定桌面用摄像头识别彩色轻质方块/小纸盒，显示实时图像、目标框和目标位置；用户确认抓取后，机械臂使用已经开源的厂家控制接口完成定位、合爪、抬起、移动、投放、释放，并展示关节反馈、进度和错误。物体移动到新的桌面位置后，视觉重新检测、标定后仍应能够抓取，不能用固定动画冒充视觉。

应用定位是 **实验室教学/嵌入式系统设计/轻量桌面分拣演示原型**。旧项目的可穿戴助残八舵机 AmazingHand 是历史研究方向，不作为本期交付，也不能宣称医疗适用性。

## 实际交付优先级

| 阶段 | 可看到的效果 | 是否需要 FPGA |
|---|---|---|
| R0：真机控制 | PC 通过原厂 SDK 查询真实反馈，低速控制机械臂、夹爪 | **不需要** |
| R1：实体抓放 | PC 控制机械臂从安全固定位置抓物，搬到投放区 | **不需要** |
| R2：**完整视觉作品，P0** | USB 相机真画面、标定、变位识别、真实抓放、界面/日志 | **不需要** |
| R3：Z19/PL 技术展示，P1 并行 | 复用原有 Z19 实板成果，展示至少一项实际可验证的 PL 参与；条件成熟再与 R2 集成 | **需要真正 PL 实测** |
| R4：语音/更多类别/ROS2 | 有余力才扩展，不能影响 R2 | 不作前置 |

**重要：** PC→ESP32 的 R2 可以独立存在并应先完成。若 PL 集成失败，保留成功的 PC 演示与失败证据；同时按照真实参赛要求评估是否需要补充 R3，绝不伪称“已完成 FPGA 集成”。

## 一眼看懂软硬件

```text
固定俯视 USB 摄像头 → PC OpenCV / 标定 / 目标确认 / 任务 UI
                                  |
                    官方 Python SDK / USB 串口
                                  |
                  RoArm-M2-S 原厂 ESP32 + 舵机 + 夹爪
                                  |
                           真实抓取与反馈

Z19 ARM PS / FPGA PL：并行开展已有成果复用与实际 FPGA 展示；
**不串在上述主链中，不作为 PC 实物运动/视觉抓放前置条件**。
```

ESP32 已有舵机内环及逆运动学。FPGA 可以处理硬件计时/状态监控或可测的控制辅助；是否能低成本集成应由现场测试决定，**不要求 FPGA 重写串口/舵机/逆运动学**。FPGA 软件 STOP 也不是物理断电装置。

## 官方源码与仓库收录情况

**核心源代码真实公开，尚未完整复制进本仓库。** 以下已核实：
- [微雪 ESP32 固件/原厂 Python 示例](https://github.com/waveshareteam/roarm_m2) @ `c6ccc5bda2eb92df2f0850d3e63cc42b81557f4f`
- [微雪 Python SDK](https://github.com/waveshareteam/waveshare_roarm_sdk) @ `d9893632aa7f5a9cb283136ab024faf3143ea7db`
- [微雪 ROS2 工程](https://github.com/waveshareteam/roarm_ws_em0) @ `f06b2ed6c1ddc5b7690975fdbba84aab626a2229`，非第一版依赖。

[详细 API、版本和许可证审计](docs/relaunch_20261020/ROARM_OPEN_SOURCE_AUDIT.md) · [Issue #14：Codex 固定 SDK、依赖和 PC 一键演示](https://github.com/Citlali6/VisionGrasp-Z19/issues/14)。官方程序能否在实际到货设备与当前 PC/Z19 环境顺利运行，**尚待实测**。

## 现有成果为什么还保留？

- **Z19 Linux/SSH**：有真实启动及通信记录；不是 RoArm 已兼容的证明。
- **IMX214 MIPI**：camera-only 固件历史实测 1080p 与 PC 约 25fps 视频；但与 MJC1-only 控制 profile **不能直接同时加载**。
- **MJC1 R2、AHIL/MuJoCo**：存在真正 PS↔PL 虚拟手反馈和 ACK 证据，但**没有驱动实体 RoArm**。
- **旧组合 MIPI+HIL bit**：仍有 DRC、外部时序/实板验证阻断，**NOT DEPLOYABLE**。
- **NCNN、Vosk**：有代码/模型与部分板端验证，但新 USB 相机/真实语音→RoArm 尚未签收。

我们不会删掉之前做过的研究；只把“不能直接复用的复杂 FPGA 工作”从实体交付关键路径上移走。旧 AmazingHand 八舵机/FMC/SCS 直接驱动与旧截止日期只是历史文档，不再是现行任务。

## 新人阅读与开发入口

[Demo-first 决策](docs/relaunch_20261020/DEMO_FIRST_POLICY.md) → [十天计划](docs/relaunch_20261020/TEN_DAY_EXECUTION.md) → [PC/ESP32/FPGA 架构](docs/relaunch_20261020/SYSTEM_ARCHITECTURE.md) → [RoArm 官方源码](docs/relaunch_20261020/ROARM_OPEN_SOURCE_AUDIT.md) → [操作与安全](docs/relaunch_20261020/HARDWARE_BRINGUP.md) → [团队上手](docs/relaunch_20261020/TEAM_ONBOARDING.md) → [历史隔离规范](docs/relaunch_20261020/DOC_STATUS_AND_RULES.md)。

任务：[总控 #6](https://github.com/Citlali6/VisionGrasp-Z19/issues/6)、[#14 厂商 SDK](https://github.com/Citlali6/VisionGrasp-Z19/issues/14)、[#7 RoArm 真机](https://github.com/Citlali6/VisionGrasp-Z19/issues/7)、[#8 PC 视觉](https://github.com/Citlali6/VisionGrasp-Z19/issues/8)、[#10 真实视觉抓放](https://github.com/Citlali6/VisionGrasp-Z19/issues/10)、[#11 验收](https://github.com/Citlali6/VisionGrasp-Z19/issues/11)。[#9 Z19/FPGA](https://github.com/Citlali6/VisionGrasp-Z19/issues/9) 并行 P1，[#12 语音](https://github.com/Citlali6/VisionGrasp-Z19/issues/12) 在主线稳定前 HOLD。

**安全**：实物底座与供电由 Citlali6 现场核验并当次批准；Codex 默认 dry-run，不得擅自下发实际运动、刷 ESP32 或更改 Z19 bit。机械臂断电可能下垂，软件 STOP 不等于物理急停；保留完整失败日志与真实录像，严格区分 PC、仿真、Z19、实物和端到端证据。

**Git 工作流**：唯一新仓库，`main` → 新工作分支 → PR → 审查/明确授权合并，禁止直接推 main、强推、修改原队长仓库。详细规则见 [AGENTS.md](AGENTS.md) 和 [docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md)。
