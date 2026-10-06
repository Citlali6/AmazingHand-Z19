# Amazing Hand AI — 人机协作智能辅助手

基于 AMD Zynq UltraScale+ MPSoC（ALINX Z19, XCZU19EG）的人机协作抓取系统。
语音指定目标 → 端侧视觉识别物体并估计尺寸 → 引导人手就位 → FPGA 实时力控完成抓取。
全系统单板自主运行，无云端依赖。

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
当前无FPGA RTL/工程，500Hz下发与两路轮询是待实测的首版候选，不能写成已实现指标。

## 目录结构

```
fpga/    PL 侧：RTL 源码、testbench、约束、一键构建脚本
host/    PS 侧：语音 / 视觉 / 策略 / 控制（双后端：软件环 vs RTL 环）
tools/   PC 侧离线工具：舵机校准、相机标定、检测验证
sim/     MuJoCo 数字孪生：抓取参数离线验证
data/    标定结果与实测指标
docs/    项目框架、设计文档、开发日志
skill/   技能包（比赛交付）
report/  设计报告（比赛交付）
```

## 快速开始（复现步骤）

> 下列是规划流程。`host/scripts/`、`fpga/scripts/`、`tools/` 当前尚未实现，不能直接执行这些计划入口。
> 已有PC模拟链路可运行 `python host/tests/smoke_test_control.py`、`python host/tests/smoke_test_backend.py`，
> 或 `python host/app/main.py --mock-voice "抓起香蕉,放下"`；通过不代表真实抓取或协议已实机核验。

1. **硬件**：ALINX Z19 + AmazingHand（8×SCS0009，串行总线）+ USB 相机 + USB 麦克风
2. **板端系统**：ALINX Ubuntu 镜像烧写（见 `docs/refer/course_s2`）
3. **环境**：`host/scripts/setup_z19.sh`
4. **FPGA**：`cd fpga/scripts && vivado -source build_project.tcl`
5. **标定**：PC 上运行 `tools/calibrate_servo.py` 与 `tools/calibrate_camera.py`
6. **运行**：`host/scripts/run_app.sh`

## 开发状态

- [x] 方案定稿与系统设计
- [x] Python协议参考模型与Host骨架（模拟测试通过，协议实物参数待复核）
- [ ] AmazingHand实物可用性与标定交接（历史日志记录已组装，本轮尚未核实）
- [ ] Z19 环境部署 / PC 工具链
- [ ] RTL 舵机总线控制器与力控状态机
- [ ] 视觉与语音链路
- [ ] 系统集成与指标实测

进度详见 [docs/log/](docs/log/)。

## 许可证

代码：Apache-2.0。机械结构继承 [AmazingHand](https://github.com/pollen-robotics/AmazingHand) 的 CC-BY 4.0。

## 致谢

- [Pollen Robotics — AmazingHand](https://github.com/pollen-robotics/AmazingHand)
- AMD Xilinx Vitis AI / PYNQ 社区
