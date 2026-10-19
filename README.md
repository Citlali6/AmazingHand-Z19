# Amazing Hand AI — 人机协作智能辅助手

基于 AMD Zynq UltraScale+ MPSoC（ALINX Z19, XCZU19EG）的人机协作抓取系统。
目标流程：语音指定目标 → 端侧视觉识别物体并估计尺寸 → 引导人手就位 → FPGA 实时力控完成抓取。
目标为全系统单板自主运行、无云端依赖；目前已完成相机基础链路，整手闭环仍待集成。

> 设计哲学：**模糊性交给 AI（PS/DPU），确定性交给 RTL（PL）**

## 系统架构

```
PS (Linux / Cortex-A53)：语音命令词识别 → YOLO 检测 + 单目尺寸估计 → 抓取策略查表 → ArUco 就位引导
PL (RTL，待实现)：单条半双工总线控制 8 个舵机 + 基于负载反馈的抓握监督与保护状态机
执行器：8 × Feetech SCS0009 → AmazingHand（pollen-robotics 开源灵巧手）
```

详细设计见 [docs/design/architecture.md](docs/design/architecture.md)。

FPGA工作计划、技术设计、施工步骤与验收见 [FPGA开发文档入口](docs/fpga/README.md)。
第一版要求在 **2026-10-15 前完成真实灵巧手抓取**；建议10-14验收交付。
现有相机工程/平台已归档，手控制 RTL 与接口仍需修订、仿真和实机验收，不能写成已完成抓取。

## 当前已验证功能（2026-10-10）

| 功能 | 实测结果 | 实现与操作说明 |
|---|---|---|
| Linux SD 启动 | ext4 系统安装、自己的 root 登录、一轮断电启动通过 | [SD 部署记录](docs/fpga/linux_sd_bringup.md) |
| 电脑直连与 SSH | PS 网口 100 Mbps 全双工，SSH/SCP/hash 核对通过 | [相机快速操作](docs/fpga/camera_quickstart.md) |
| CAM0 采集 | IMX214 真正 1920×1080，连续十分钟、DMA 错误/空样本为零 | [Linux 相机源码](host/camera_linux/README.md) |
| 高清实时视频 | 30 秒收到 757 张不同的 1080p JPEG，约 25.16 fps，逐张解码通过 | [验收记录](docs/fpga/linux_camera0_bringup.md) |
| 控制及故障处理 | 启停、手动焦距、过期画面拒绝、采集异常后停 DMA/重新启动通过 | [功能及交付清单](docs/fpga/camera_delivery_20261010.md) |
| 相机硬件归档 | 已使用的 bit/XSA、原 BD/XDC、依赖 IP 源码及文件 hash | [硬件工程说明](fpga/camera_hw/README.md) |

当前没有开机自动加载相机、第二路验收、自动对焦、目标识别或真实灵巧手闭环。
约 25 fps 指电脑接收测试，不代表固定 30 fps 或无丢帧的传感器采集。

## 目录结构

```
fpga/    相机硬件工程/bit/XSA、历史裸核验证；手控制 RTL/仿真/构建输入
host/    Linux 相机驱动/采集/实时预览、板端脚本；语音/视觉/控制骨架
tools/   SD 制作/安全检查、串口日志与测试；标定工具按实施状态确认
sim/     MuJoCo 数字孪生：抓取参数离线验证
data/    标定结果与实测指标
docs/    项目框架、设计文档、开发日志
skill/   技能包（比赛交付）
report/  设计报告（比赛交付）
```

## 快速开始

**本仓库迁移入口：[下载、启动与完整性记录](docs/migration/README.md)。**
原仓库的 Issue、PR 讨论、评审与变更补丁已补存为 [可离线查阅的归档](docs/migration/upstream_archive_20261019_v2/README.md)。
虚拟手模型已随迁移分支完整保存；本机已准备独立 PC 环境，可双击 `start_virtual_hand.bat` 打开交互虚拟手。
PL 控制观察入口为 `start_mjc1_observer.bat`，需配套板端 MJC1 R2 程序与 SSH 转发，操作见迁移说明。

微雪 USB TO AUDIO 的语音基础入口、离线资料与到货步骤见 [USB麦克风说明](docs/voice/USB_MICROPHONE.md)。当前已补采音/识别源码，真实麦克风验收及语音→PL接入待完成。
含中文模型和板端依赖的完整离线包见 [麦克风部署包下载](deliverables/voice_usb/README.md)。

相机实机操作从 [相机快速操作](docs/fpga/camera_quickstart.md) 开始。
当前硬件为 **Z19 + FL0214/IMX214 MIPI 第一通道**，板端使用 Linux 5.4/PetaLinux 2020.2 基线。
Git 中包含源码、平台与已验证相机二进制；SD 系统镜像、登录密码/SSH 私钥和现场录像留在本机。
其他成员准备同一基线系统及自己的 SSH 认证后，按 [交付清单](docs/fpga/camera_delivery_20261010.md) 复现。

已有 PC 模拟链路可运行 `python host/tests/smoke_test_control.py`、`python host/tests/smoke_test_backend.py`，
或 `python host/app/main.py --mock-voice "抓起香蕉,放下"`；通过不代表真实抓取或协议已实机核验。
新增实时交互入口：`.venv/Scripts/python.exe host/app/main.py --mujoco`，支持当次输入控制、
MuJoCo 实测反馈和锁存停止；环境准备与按键操作见 [实时控制说明](sim/LIVE_CONTROL.md)。
该演示是手部仿真控制，不代表物体抓取或实板 HIL 已验收。
整手接线、舵机标定、语音/识别模型和闭环运行步骤仍按 [实施状态](docs/fpga/implementation_progress.md) 推进。

## 开发状态

- [x] 方案定稿与系统设计
- [x] Python协议参考模型与Host骨架（模拟测试通过，协议实物参数待复核）
- [ ] AmazingHand实物可用性与标定交接（历史日志记录已组装，本轮尚未核实）
- [x] Z19 Linux SD、一次冷启动、电脑直连 SSH
- [x] 单路 MIPI 相机 Linux 采集与 1080p 实时预览
- [x] 相机工程/已验证平台/源码/功能说明归档
- [ ] RTL 舵机总线控制器与力控状态机
- [ ] 视觉与语音链路
- [ ] 系统集成与指标实测

进度详见 [docs/log/](docs/log/)。

## 许可证

项目代码默认 Apache-2.0，以各文件声明为准。Linux 相机内核模块声明 GPL；
归档的供应方 IP 保留原有版权/许可，Digilent 核包含 MIT 声明，不统一重授权为 Apache。
机械结构继承 [AmazingHand](https://github.com/pollen-robotics/AmazingHand) 的 CC-BY 4.0。

## 致谢

- [Pollen Robotics — AmazingHand](https://github.com/pollen-robotics/AmazingHand)
- AMD Xilinx Vitis AI / PYNQ 社区
