# AmazingHand-Z19 — 视觉引导抓取与 FPGA 实时控制系统

**正式研发仓库：** [Citlali6/AmazingHand-Z19](https://github.com/Citlali6/AmazingHand-Z19) · **正式基线：** `main` · **项目负责人：** Citlali6

> **当前路线（2026-10-20 起）**：RoArm-M2-S 成品桌面机械臂 + ALINX Z19 (XCZU19EG) + 实验室 USB 摄像头。为 10 天内交付可重复展示的真实工程而调整。旧“可穿戴 AmazingHand 八舵机、FMC 直驱、手背 ArUco 引导、PL 舵机力控”是**历史方案，不是当前开发任务**。本 README 和 [现行方案](docs/relaunch_20261020/README.md) 是新人第一入口。

## 项目介绍与用途

暂定正式题目：《基于 Zynq UltraScale+ MPSoC 的多模态视觉引导抓取与 FPGA 实时控制系统》。

面向实验室教学演示、固定桌面轻量物品自动抓放/分拣：用户通过界面选择目标（可选离线语音）；固定 USB 摄像头读取桌面真实画面、输出目标位置；Z19 的 Cortex-A53 / Linux PS 进行目标确认、坐标标定和动作规划；Z19 PL 在实际命令链上执行阶段授权、序号/超时检查、STOP 锁存和反馈监督；由 PS USB 串口将获授权命令发送给成品 RoArm-M2-S 的 ESP32 控制器，驱动其夹爪完成抓取、搬运、放置。

这是**待完成的工程目标**，不是宣布已经联调成功的功能。原本的助残可穿戴愿景已不作为本期实物交付或安全适用范围；本期不宣称医疗级、工业级、物理急停认证或 FPGA 电流/力矩伺服能力。

## 读文档请按这个顺序

| 顺序 | 正式入口 | 看什么 |
|---|---|---|
| 1 | [十天交付总说明](docs/relaunch_20261020/README.md) | MVP、项目边界、历史验证资产 |
| 2 | [系统架构与接口](docs/relaunch_20261020/SYSTEM_ARCHITECTURE.md) | PS/PL/ESP32职责、USB/坐标、安全 |
| 3 | [微雪 RoArm 官方开源核查](docs/relaunch_20261020/ROARM_OPEN_SOURCE_AUDIT.md) | 固件/SDK/ROS2 固定版本、API、许可证 |
| 4 | [十天执行计划](docs/relaunch_20261020/TEN_DAY_EXECUTION.md) | D1-D10、止损线、队员职责 |
| 5 | [硬件接入指南](docs/relaunch_20261020/HARDWARE_BRINGUP.md) | 摄像头、串口、供电、STOP和上板许可 |
| 6 | [新成员 / Codex 协作](docs/relaunch_20261020/TEAM_ONBOARDING.md) | 如何阅读、提交、测试、Review |
| 7 | [现行文档权威性与旧项目隔离规范](docs/relaunch_20261020/DOC_STATUS_AND_RULES.md) | 遇到矛盾听哪份，历史目录怎么用 |

**当前执行看板：** [总控 Issue #6](https://github.com/Citlali6/AmazingHand-Z19/issues/6)，[RoArm 串口 #7](https://github.com/Citlali6/AmazingHand-Z19/issues/7)、[视觉 #8](https://github.com/Citlali6/AmazingHand-Z19/issues/8)、[FPGA #9](https://github.com/Citlali6/AmazingHand-Z19/issues/9)、[实体联调 #10](https://github.com/Citlali6/AmazingHand-Z19/issues/10)、[终测 #11](https://github.com/Citlali6/AmazingHand-Z19/issues/11)、[可选语音 HOLD #12](https://github.com/Citlali6/AmazingHand-Z19/issues/12)。

## MVP 工作链（**待实现和联调**）

```text
USB UVC 摄像头(固定俯视) → PS/PC 真实帧定位 → 桌面标定及人工确认
                                        ↓
                           Z19 PS 动作规划/串口桥
                                        ↕
                           Z19 PL 动作授权与 STOP
                                        ↓
                     Z19 PS USB 串口 → RoArm ESP32 → 舵机与夹爪
                                        ↑
                                   实体关节反馈
```

优先相机接 Z19 PS USB Host；当前 Linux UVC 驱动兼容性**未验收**，超过规定排障时间切“PC 取图 → Z19 执行 FPGA 控制”的保底架构，必须如实标注。机械臂实际控制必须经过有意义的 PL 动作授权；ESP32 才负责真实底层伺服。不要把 USB 串口传输描述为 PL 直接产生 PWM 或 1Mbps SCS 舵机协议。

演示必须是**新的真实画面 → 目标变位定位 → PL 授权 → 实体抓取投放 → 反馈和异常记录**；彩色块 / 规则检测可用来保证第一版稳定，但不冒充 YOLO/NCNN 准确率。语音/ROS2/大型模型是可选项，不能阻塞 P0。

## 当前已实现的历史资产（与本期交付严格区分）

| 资产 | 真实证据或资料 | 不得外推为 |
|---|---|---|
| Z19 Linux SD、SSH | 已启动、网络通信、文件传输：[`docs/fpga/linux_sd_bringup.md`](docs/fpga/linux_sd_bringup.md) | RoArm USB 串口已连接 |
| IMX214 camera-only | 1920×1080、PC 约 25 fps 接收：[`host/camera_linux/README.md`](host/camera_linux/README.md) | UVC 驱动可用，或与控制 PL 已同时运行 |
| AHIL / MJC1 R2 | 原 MuJoCo HIL，有真实 PL 状态与 ACK：[`fpga/mjc1_fpd/README.md`](fpga/mjc1_fpd/README.md) | PL 已驱动真实 RoArm |
| NCNN 视觉工作 | 历史分支对 car 有真实推理；苹果误判 orange、保温瓶漏检 | 新桌面物品已识别成功 |
| USB Vosk 离线包 | [语音资料](docs/voice/USB_MICROPHONE.md) 有源码模型 | 麦克风与实物链路已经验收 |
| 组合 MIPI+HIL | 仅结构/时序局部验证，仍有 DRC 和 I/O 约束阻断 | **不可加载实验 bit** |
| RoArm-M2-S 与实验室 USB 相机 | 用户已下单 S 标准整机；USB 摄像头曾在树莓派可用 | 新实物已联调或 Z19 可读取相机 |

旧 AmazingHand MuJoCo / SCS / RTL / FM​​C 等资源**完整保留供研究、复现和追溯**，但新机械臂采用原厂 ESP32 的官方串口协议，不能盲搬旧八路舵机指令及力控策略。

## 新人如何开始

1. 阅读上方七个入口及根目录 [AGENTS.md](AGENTS.md)、[Git 工作流](docs/GIT_WORKFLOW.md)。
2. 在 [总控 #6](https://github.com/Citlali6/AmazingHand-Z19/issues/6) 回复 GitHub 账号、认领视觉 A / 机械臂 B、能投入时间与现场硬件时段。
3. Codex 只在负责人明确启动对应 Issue 后，在最新 `main` 建个人分支、离线开发和测试、提交 PR；代码与实板证据分级回报。未获本次独立授权，不得重配 PL、刷 ESP32 固件、改 SD/内核或自动发机械臂运动命令。
4. 物理演示必须有**现场操作者与可触及的独立 12V 断能手段**；软件 STOP 锁存不等于实体伺服能立即停止。失败日志保留，不允许选择性排除。

原有 PC 旧手模型仍可用 `setup_pc.bat`、`start_virtual_hand.bat` 打开；它们只用于**历史功能回归**，不是 RoArm 自动抓取的启动命令。详见 [迁移存档入口](docs/migration/README.md)。

## 仓库目录和研发边界

`fpga/`：Z19 PL 原 RTL、MJC1 R2、历史相机/组合工程，新增 RoArm 授权 IP 应独立开发；
`host/`：现有 Host 与视觉/语音/控制抽象，新增 UVC 输入及 RoArm serial 适配器须与旧 SCS 后端隔离；
`sim/`、`AmazingHand/`：历史八执行器虚拟手和模型；
`deliverables/`：迁移离线包与校验档案；
`docs/relaunch_20261020/`：**当前项目设计与执行权威入口**；
`docs/design/`、`docs/fpga/` 中部分文档是旧技术方案或当时快照，明确标识后**只读追溯**；
`docs/log/`、`docs/migration/`：历史实验与迁移依据，不覆盖、不伪造新实测。

许可证按文件和上游声明分别遵守：项目原代码 Apache-2.0，旧结构/模型存在 CC-BY 等，RoArm 固件和 Python SDK 另有 GPL/AGPL 条款；不可简单整体重授权。

**唯一写入仓库：** `Citlali6/AmazingHand-Z19`，旧仓库永久只读。严格遵守最新 `main → 独立分支 → PR → 有权限成员按当轮授权合并`。