# FPGA辅助视觉抓取系统｜文档权威性与旧资产隔离规范

> 生效：2026-10-20。此处规定阅读和研发优先级，不重写、删除历史记录或改变既有实验的证据等级。

> **统一命名规则：** 当前展示/报名建议作品名为 **「FPGA辅助视觉抓取系统」**。GitHub 仓库地址仍是 `Citlali6/AmazingHand-Z19`，只是技术历史沿用的固定地址，**不代表当前还以 AmazingHand 灵巧手为研发目标**。任何公开展示页面的新标题、报告首页、队友介绍和后续任务文案应使用当前作品名；**不得批量替换** GitHub URL、原作者署名、历史实验名称、源码 import/资源路径和 Git 历史。若决定修改 GitHub 仓库 slug，必须由负责人另行确认并安排 clone/remote/文档/CI 链接迁移。

> **2026-10-20 后续用户确认：Demo-first 决策拥有优先级。** 必须先执行 [DEMO_FIRST_POLICY.md](DEMO_FIRST_POLICY.md) 中 R0→R1→R2 实体/视觉演示，#9 FPGA 独立 P1 并行，**不再是 #10 真实视觉抓放的前置**。旧计划中“必须 PL 授权才能串口运动”已废止；保留安全限位、现场授权和失效保护。

## 1. 版本优先级与唯一真相源

1. **现场实际证据**：Z19/机械臂/摄像头真实运行日志、真实固件 SHA 和操作回执；只对测试过的设备/配置有效。
2. **新仓库最新可用代码和 PR**：以 `Citlali6/AmazingHand-Z19` 当前 `main`、未合并 PR 的准确分支/HEAD 为准；PR 中代码不能直接称 `main` 已实现。
3. **本轮已授权目标与执行任务**：`docs/relaunch_20261020/DEMO_FIRST_POLICY.md`、总控 Issue #6 与 #7–#12/#14；计划不是实测。
4. **现行仓库操作规则**：`AGENTS.md` 与 `docs/GIT_WORKFLOW.md`；不因历史文档的旧审批要求、旧仓库 URL 改变。
5. **历史技术方案和存档**：旧 `docs/design/`、`docs/fpga/` 内标记为“历史方案”的文件、旧 `docs/log/`、`docs/migration/`、旧模型、旧 PR；仅用于参考/溯源，不得抢占本期任务优先级。

当第 1 项真实数据与方案冲突，应记录差异、调查原因；不得悄悄以设计文件覆盖实验事实。对于新版未实现的寄存器、FPGA时序和设备驱动必须标 NOT VERIFIED。

## 2. 已退役思想与继续继承的技术成果

| 旧方案 / 旧指令 | 2026-10-20 当前处理 |
|---|---|
| 可穿戴助残仿生手，队长提供整手 | **退役为历史愿景**。当前固定桌面 RoArm-M2-S 成品机械臂，用户 Citlali6 负责交付管理 |
| 8×SCS0009 / FMC 引脚 / TTL 半双工直驱 | **不作为主线**，不再购买 FMC 或 1.8V/5V 电平转换器支持该方案；当前 RoArm ESP32 使用官方 USB 串口 |
| 旧“PS↔PL 契约 v0.2.2” | **旧手实验协议**，非当前 RoArm 地址/寄存器真相。先实读 MJC1 R2 / AHIL 源码和 2020.1 实测，再为 RoArm 冻结独立 ABI |
| PL 直接 1 kHz 舵机/力矩闭环 | **不可宣称**。本期 PL 验证序号、授权、超时、STOP、反馈；ESP32 做底层伺服，停止物理效果单独测 |
| 旧“10-14/15 实物整手交付”与旧队长分工 | **历史过期**。本期 D1 10/20–D10 10/29，A 视觉、B RoArm、Citlali6 实体授权 |
| 相机必须使用 IMX214 MIPI 与组合 bit | **当前不推荐**。USB UVC 优先，若 Z19 内核不支持，PC 取图→Z19 PS→PL 保底；旧未签收组合 bit 禁止部署 |
| 15 类物品/每类 20 次/语音必选/ROS2/LLM/DPU 优先 | **本期不强制**。先 1–2 类易抓小物品、三个位置、真实 FPGA 授权与实体抓放；语音 #12 HOLD |
| 使用原 AmazingHand MuJoCo 作为 RoArm 机械臂仿真 | **禁止混称**。旧 MuJoCo 仅历史八执行器手模型的虚拟回归，新 RoArm 如需模拟先验明模型和标定 |
| “已有整手/相机/视觉/控制全通过” | 逐模块查证：原相机-only、HIL-only 曾通过，组合 bit NOT DEPLOYABLE，新实物动作 NOT VERIFIED |

继承有效的：Z19 Linux 启动与 SSH、老 IMX214 相机采集证据、AHIL/MJC1 R2 实板握手及 MMIO经验、NCNN 导出与失败诊断、Vosk 离线资料、安全停止思想、XSim/Tcl 验证与迁移审计。不删、不偷偷改写旧文件，严守测试层级。

## 3. Codex 和队友每个任务必须遵守

- 唯一目标 `Citlali6/AmazingHand-Z19`：写入前确认 origin、当前分支、工作区；旧 Tom 仓库永久只读；所有新 Issue/PR 是**新仓库编号**。
- 以最新 main 起独立功能分支，最小 diff，原始实验失败和固件 hash 均保留；经实际测试→PR→人类审核/有权限成员按任务授权决定合并。不得直接 push main、强推或删除别人的分支。
- 先读相关源实现，不准以设计稿断言程序已存在；旧路径不能直接当新 RoArm 已运行代码。任何 SDK 复用标记 GPL/AGPL 边界。
- 任务证据标准：`PLAN` / `CODED` / `PC TESTED` / `SIM TESTED` / `Z19 TESTED` / `ROARM TESTED` / `E2E TESTED` / `BLOCKED`，每次记录 commit、命令、exit code、设备 profile、报告及失败条件。
- 首次上板与每次新固件/电源/机械运动：由 Citlali6 对**具体动作**再次授权；独立于 Issue 文字。Codex 无权直接刷机、执行 `middle_set`、重装内核、覆盖 SD、强制部署旧组合 bit 或自动发运动指令。
- PS/PL/ESP32 是三层独立证据：授权寄存器有效≠串口命令被 MCU 处理≠机械臂抓稳；软件 STOP≠实体断电。
- 一块 Z19 和一只实体机械臂由唯一现场操作者占用；视觉与 RoArm 两队在不同分支并行、统一接口负责人批准冻结，禁止互相覆盖 `host/app/main.py`。
- D1–D10 中 P0：PC 官方 SDK / 安全串口、实体固定点抓放、PC 视觉变位抓放、UI 和安全验收；#9 FPGA 为独立 P1，不得阻断 #10。#12 语音、ROS2/MoveIt/复杂模型为后续可选。
- 当天追加**新日期的**变更决策/现场数据；历史 `docs/log/`、归档的 README、旧作者署名与 GPL 文件保持原样。重大改向必须补充依据、受影响模块、回退方式、负责人确认。

## 4. 历史文档目录使用说明

- `docs/project_framework.md`：替换为当前项目概览；旧版本可通过仓库 Git history 检索。
- `docs/procurement.md`：替换为当前成品 RoArm 的实际购买状态与物料；旧八舵机 BOM 在 Git 历史，**不再执行剪 USB 线取电等旧建议**。
- `docs/design/architecture.md`：原 AmazingHand 手指工作分解的历史规划，不是当前文件清单。
- `docs/design/interface.md`：原 SCS/8 舵机协议 v0.2.2，仅历史手链；当前 RoArm 逻辑约定参见 `docs/relaunch_20261020/SYSTEM_ARCHITECTURE.md`。
- `docs/fpga/README.md` 及 `technical_design.md`、`implementation_guide.md`、`interface_proposal.md`、`verification_acceptance.md`：2026-10 上旬旧手计划，为参考/实验审计；新执行在 #9 和新的 RoArm 专用实现中。
- `docs/fpga/implementation_progress.md`：10/10 **历史现场快照**，不能用来说明 10/20 的最新状态。真正过往结果依然保留，后续阶段写新日志/新证据。
- `docs/voice/`、`fpga/mjc1_fpd/`、`host/camera_linux/`：**真实技术资产**，可能含特定设备路径；复现必须按相应对应 profile，且不代表新系统通过。
- `docs/migration/`、`deliverables/`、`sim/`、`AmazingHand/`：可追溯历史来源，禁止批量换链接、删许可证或修改原始 hash。

## 5. 文档变更的验收要求

每次开发合并前核查：根 README 有没有错误的旧目标；对应 Issue 的状态是不是仍正确；所引用路径在当前分支是否存在；任何“已通过”是否有真实输出证据；与当前硬件供电/安全范围是否矛盾；是否误把历史 Issue/PR 编号当新仓库任务。发现过期说明只能在新工作分支用 PR 修订，保留历史来源。
