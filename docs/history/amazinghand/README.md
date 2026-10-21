# 旧灵巧手设计的历史入口

2026-10-21，负责人要求停止 AmazingHand 灵巧手方向，清理过时设计，保留机械臂项目可复用的部分。旧设计正文和过期 PR 草稿已从当前开发文档移出；五个仍被源码或日志引用的路径仅保留简短跳转页。

当前开发从 [Demo-first 决策](../../relaunch_20261020/DEMO_FIRST_POLICY.md)、[机械臂架构](../../relaunch_20261020/SYSTEM_ARCHITECTURE.md)和[PC 接口契约](../../development/PC_MVP_CONTRACT.md)开始。

## 如何找回原文

清理前完整版本为 `ed4965cba65f3b36303b9e661115e33268fd1741`，原文可通过 Git 查看：

```powershell
git show ed4965cba65f3b36303b9e661115e33268fd1741:docs/design/interface.md
```

| 原文路径 | 原用途 |
|---|---|
| `docs/design/architecture.md` | 八舵机灵巧手系统架构与旧目录规划 |
| `docs/design/interface.md` | 旧 SCS PS/PL 接口 v0.2.2 |
| `docs/fpga/implementation_guide.md` | 旧灵巧手接线与施工步骤 |
| `docs/fpga/interface_proposal.md` | 未冻结的旧接口提案 |
| `docs/fpga/technical_design.md` | 旧总线/抓握监督设计 |
| `docs/pr/001-scs-protocol-golden-model.md` | 过期 SCS 协议 PR 草稿 |
| `docs/pr/002-host-skeleton.md` | 过期 Host 骨架 PR 草稿 |
| `docs/pr/003-sim-model-rtl.md` | 过期模型/RTL PR 草稿 |

本机还保留校验过的原文副本：`F:\嵌入式fpga比赛\整理记录\2026-10-21\旧灵巧手设计原文`；旧仓库和全部本地分支存于 `F:\嵌入式fpga比赛\工程project开发\历史归档\旧仓库`。

## 继续保留的技术资产

Z19 Linux/SSH、相机源码和 BD/XDC/IP、bit/XSA、MJC1/HIL 实测证据、语音资料、开发日志、模型来源与许可证均保留。`implementation_progress.md` 和 `verification_acceptance.md` 含真实历史快照/审查结果，保留原文；不能据此声称 RoArm 已通过实物验收。

旧 `AmazingHand/`、SCS 代码和手部仿真仍是历史研究资产。本次整理没有改动这些代码，也没有将旧手模型改称机械臂模型。
