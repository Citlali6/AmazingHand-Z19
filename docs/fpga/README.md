# Z19 / FPGA 可复用资产入口

当前项目为 RoArm-M2-S 视觉抓放。PC + USB 摄像头 + 原厂 SDK 是 P0；Z19/PL 为独立 P1，执行依据见 [Demo-first 决策](../relaunch_20261020/DEMO_FIRST_POLICY.md)和[现行架构](../relaunch_20261020/SYSTEM_ARCHITECTURE.md)。

## 已有工程与实测记录

| 资产 | 入口 | 使用边界 |
|---|---|---|
| Z19 Linux / SD / SSH | [启动记录](linux_sd_bringup.md) | 历史已测配置；不是 RoArm 联调结果 |
| IMX214 相机 | [快速操作](camera_quickstart.md)、[交付清单](camera_delivery_20261010.md)、[验收记录](linux_camera0_bringup.md) | camera-only profile，独立于当前 PC USB 相机 |
| 相机硬件归档 | [BD/XDC/IP、bit/XSA](../../fpga/camera_hw/README.md) | 保留源码、配置、许可证和配套 hash |
| MJC1 R2 / HIL | [硬件与实板记录](../../fpga/mjc1_fpd/README.md) | 旧虚拟手证据，不代表驱动实体 RoArm |
| 历史进度与审查证据 | [10/10 快照](implementation_progress.md)、[早期审查](verification_acceptance.md) | 只说明当时配置与执行结果 |

旧 MIPI+HIL 组合 bit 仍为 **NOT DEPLOYABLE**。本次目录整理没有重新构建、加载或验证任何固件。

## 旧方案处理

旧八舵机/FMC/SCS 施工和技术设计已移出当前开发正文；[历史资料索引](../history/amazinghand/README.md)提供固定版本与本机原文。旧截止日期、采购与整手验收要求不再作为任务依据。
