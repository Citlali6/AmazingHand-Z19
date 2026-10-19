# 文档导航（2026-10-20 起）

> **先辨认当前路线还是历史材料。** 当前工程：RoArm-M2-S 成品机械臂 + Z19 PS/PL + USB 摄像头，目标十天内交付真实抓放；最初 AmazingHand 八舵机可穿戴手路线已退役为历史，不要据其旧预算/接口/旧分工直接执行。

## 当前可执行的项目文档
- [仓库首页 / 最新项目状态](../README.md)
- [十天项目简介、目标与验收](relaunch_20261020/README.md)
- [架构与 PS/PL/ESP32 控制边界](relaunch_20261020/SYSTEM_ARCHITECTURE.md)
- [官方 RoArm 固件/SDK/ROS2 核实](relaunch_20261020/ROARM_OPEN_SOURCE_AUDIT.md)
- [10/20–10/29 排期、分工和止损](relaunch_20261020/TEN_DAY_EXECUTION.md)
- [接线、供电、串口、摄像头与安全](relaunch_20261020/HARDWARE_BRINGUP.md)
- [新人/Codex 工作规范与审查](relaunch_20261020/TEAM_ONBOARDING.md)
- [**文档权威性与历史路线隔离**](relaunch_20261020/DOC_STATUS_AND_RULES.md)
- [当前项目概述](project_framework.md)
- [**最新采购状态**](procurement.md)
- [Git 工作流](GIT_WORKFLOW.md)和[强制 Codex 规则](../AGENTS.md)

### 最新 GitHub 开发任务
[总控 #6](https://github.com/Citlali6/AmazingHand-Z19/issues/6) → [#7 RoArm 串口](https://github.com/Citlali6/AmazingHand-Z19/issues/7)、[#8 USB 视觉](https://github.com/Citlali6/AmazingHand-Z19/issues/8)、[#9 FPGA](https://github.com/Citlali6/AmazingHand-Z19/issues/9) → [#10 真机联调](https://github.com/Citlali6/AmazingHand-Z19/issues/10) → [#11 验收](https://github.com/Citlali6/AmazingHand-Z19/issues/11)。[#12 语音](https://github.com/Citlali6/AmazingHand-Z19/issues/12) 是 P1/HOLD。任务发布不等于 Codex 已经执行或板卡获得操作许可。

## 历史真实技术资产（仍值得利用）
- [Z19 Linux SD/SSH 实测](fpga/linux_sd_bringup.md)
- [IMX214 采集与旧相机固件归档](../host/camera_linux/README.md)
- [MJC1 R2 实板 HIL 记录](../fpga/mjc1_fpd/README.md)
- [Vosk USB 离线资料](voice/USB_MICROPHONE.md)
- [迁移与全部旧 Issue/PR 内容](migration/README.md)
- [原设计结构（历史）](design/architecture.md)
- [旧 8 舵机 SCS PS/PL 接口（历史）](design/interface.md)
- [旧 FPGA 工程计划（历史）](fpga/README.md)
- [旧相机和整手进度快照（2026-10-10）](fpga/implementation_progress.md)

历史文件的实验结果必须限定到真实测试的旧配置，**不能直接冒充现在的 RoArm 真实联调**。尤其组合 MIPI/HIL 实验 bit **NOT DEPLOYABLE**；旧 AmazingHand MuJoCo 模型不是 RoArm 的模型。新的现场测试请新建日期日志并准确记载 commit/固件/hash。

## 读文档时的判断顺序
真实设备/源代码证据 → 当前 main 与具体 PR → 当前负责人批准的方案/Issue → AGENTS/工作流 → 历史文档（仅溯源）。任何过时的人事、物料和旧日期不得自动覆盖现行决策。详见[文档规范](relaunch_20261020/DOC_STATUS_AND_RULES.md)。
