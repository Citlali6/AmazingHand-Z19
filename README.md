# Amazing Hand AI — 人机协作智能辅助手

基于 AMD Zynq UltraScale+ MPSoC（ALINX Z19, XCZU19EG）的人机协作抓取系统。
语音指定目标 → 端侧视觉识别物体并估计尺寸 → 引导人手就位 → FPGA 实时力控完成抓取。
全系统单板自主运行，无云端依赖。

> 设计哲学：**模糊性交给 AI（PS/DPU），确定性交给 RTL（PL）**

## 系统架构

```
PS (Linux / Cortex-A53)：语音命令词识别 → YOLO 检测 + 单目尺寸估计 → 抓取策略查表 → ArUco 就位引导
PL (RTL)：舵机总线控制器（8路, 1kHz 回读） + 力控抓握状态机（堵转/超温保护）
执行器：8 × Feetech SCS0009 → AmazingHand（pollen-robotics 开源灵巧手）
```

详细设计见 [docs/design/architecture.md](docs/design/architecture.md)。

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

> 完整复现说明整理中，决赛版将包含从零到演示的每一步。

1. **硬件**：ALINX Z19 + AmazingHand（8×SCS0009，串行总线）+ USB 相机 + USB 麦克风
2. **板端系统**：ALINX Ubuntu 镜像烧写（见 `docs/refer/course_s2`）
3. **环境**：`host/scripts/setup_z19.sh`
4. **FPGA**：`cd fpga/scripts && vivado -source build_project.tcl`
5. **标定**：PC 上运行 `tools/calibrate_servo.py` 与 `tools/calibrate_camera.py`
6. **运行**：`host/scripts/run_app.sh`

## 开发状态

- [x] 方案定稿与系统设计
- [x] AmazingHand 机械组装与舵机接线
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
