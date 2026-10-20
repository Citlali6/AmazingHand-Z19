# RoArm-M2-S 官方开源工程实核与最快 PC 上手路线

> **Demo-first 最新说明（2026-10-20）**：本官方固件/SDK 审计用于让 Codex **最快在 PC 运行原厂 Python 接口并控制真实 RoArm**，**不应先移植 Z19** 或要求 FPGA 授权。三个官方仓库的链接和 SHA 已核实，但实际原厂 ESP32/SDK **全量源码并未复制进当前仓库**；由 [Issue #14](https://github.com/Citlali6/VisionGrasp-Z19/issues/14) 管理版本锁、依赖许可与 PC 使用说明。ROS2 非十天前置。到货固件与 API 兼容性仍需现场实测，注意厂商示例开机阶段可能主动移动机械臂。

> 来源审计日期 2026-10-20。下列 GitHub SHA 为这次实际读取的公开分支 HEAD，只记录官方文件/接口存在的事实；未到货时**没有实机兼容证据**。固定上游版本后再引入代码，不跟随远端 `main` 自动升级。

## 1. 购买机型与机械基础

- 已下单 **Waveshare RoArm-M2-S** 标准整机，4 自由度桌面机械臂，附夹爪、ESP32 主控、独立电源、USB 线和固定配件；产品规格由微雪官方网页核实，淘宝实际发货配件以开箱清点为准。
- 原厂 ESP32/总线舵机负责真实关节位置伺服与 IK。四自由度只适合受限抓取工作域，末端姿态/碰撞回避能力不可按六轴机器人宣称；官方负载参数不是我们已测的实际可抓重量。
- 包装照片中的摄像头**支架不等于摄像头**。实验室已有曾在树莓派使用的 USB 摄像头，暂不采购额外相机，实际 UVC 设备型号与 Z19 兼容性待验收。
- 微雪官方：https://www.waveshare.net/shop/RoArm-M2-S.htm
- 微雪上手文档：https://docs.waveshare.net/RoArm-M2/Preparation-Before-Use/ 、https://docs.waveshare.net/RoArm-M2/Getting-Started-Quickly/

## 2. 上游仓库已核实

| 来源 | 当次官方 HEAD | 资料和实际检查 | 用途/限制 |
|---|---|---|---|
| https://github.com/waveshareteam/roarm_m2 | `c6ccc5bda2eb92df2f0850d3e63cc42b81557f4f` | 有 `RoArm-M2_example/` ESP32 固件、`RoArm-M2_python/`、README；配置源码列出关节 ID、机械结构尺寸、默认舵机控制等；GPL 系列声明 | 固件参考，**不在 D1-D3 重新刷写**。出厂固件是否完全等同 GitHub HEAD 未验证 |
| https://github.com/waveshareteam/waveshare_roarm_sdk | `d9893632aa7f5a9cb283136ab024faf3143ea7db` | 已实际读 `roarm_sdk/roarm.py`、`doc/roarm_m2_zh.md`、`requirements.txt`、LICENSE。SDK `roarm_type='roarm_m2'`、串口 115200、`gripper_type='angular_direct'`；`pyserial` 与 `requests` 依赖 | 最快 PC 测试/协议源；LICENSE 为 AGPL-3.0，若复制 SDK 到参赛工程需依法审查相应开源义务 |
| https://github.com/waveshareteam/roarm_ws_em0 | `f06b2ed6c1ddc5b7690975fdbba84aab626a2229` (`ros2-humble`) | 实际存在 ROS2 工程和源目录 | **只作为以后参考**：D1-D10 不将 ROS2/MoveIt 安装列为前置任务 |

具体官方文件：
- [SDK README（安装、型号）](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/README.md)
- [中文 API 及参数](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/doc/roarm_m2_zh.md)
- [Python 实际连接与请求实现](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/roarm_sdk/roarm.py)
- [ESP32 RoArm 关节配置](https://github.com/waveshareteam/roarm_m2/blob/c6ccc5bda2eb92df2f0850d3e63cc42b81557f4f/RoArm-M2_example/RoArm-M2_config.h)
- [微雪 ROS2 工程](https://github.com/waveshareteam/roarm_ws_em0/tree/f06b2ed6c1ddc5b7690975fdbba84aab626a2229)

## 3. 已确认的官方 API（不是我们板端测试）

```python
from roarm_sdk.roarm import roarm
arm = roarm(roarm_type="roarm_m2", port="/dev/ttyUSB0",
            baudrate=115200, gripper_type="angular_direct")

# 以下为厂家存在的接口名称，实际运动要经本工程安全门禁：
angles = arm.joints_angle_get()
feedback = arm.feedback_get()  # [x,y,z,j1,j2,j3,j4]（官方文档口径）
# arm.move_init()
# arm.joint_angle_ctrl(joint=1, angle=..., speed=..., acc=...)
# arm.joints_angle_ctrl(angles=[...], speed=..., acc=...)
# arm.gripper_angle_ctrl(angle=..., speed=..., acc=...)
# arm.pose_ctrl(pose=[x_mm,y_mm,z_mm,gripper_angle_deg])
# arm.torque_set(cmd=0)
```

官方文档：`joints_angle_get` 返回 4 个角度；`feedback_get` 返回 XYZ 与 4 个关节弧度，XYZ 单位 mm；`pose_ctrl` 的 xyz 单位 mm，末端角度用 degree。当前 SDK 默认 `gripper_type=angular_direct` 对 S 版做夹爪角度取反；**不应自行假定 0° 是张开或闭合**，须在低速台架观测并冻结映射。SDK 的 HTTP 模式文档明确仅发控制，读取反馈和拖动示教须走串口。

**严格区分三层状态**：
1. Python API 返回/串口已发送；
2. ESP32 接受命令/有反馈；
3. 关节真正在目标容差内稳定并且物体被夹紧。
这三者不能互为证据；真抓成功需实物视频和动作日志。

### 官方参数范围（仅文档约束，仍需更严格现场软限位）
- 单关节角度范围：J1 -180~180°、J2 -90~90°、J3 0~180°、J4 0~90°；
- 厂商 SDK 给出的 speed 1~4096、acc 1~254，并不意味着我们第一天可以使用最大值；
- 位置接口输入的厂家允许几何坐标范围不等于机械碰撞安全区域。每一姿态需实物标定、限速与机械空间检查。
- 机械臂固件可能具有开机运动、自检/力矩逻辑；先查实际版本并进行空载、低速、无人在运动范围内的验证，不要自动 `middle_set()` 或刷出厂固件。

## 4. 正确的最短上手路径（PC 优先；Z19 测试为独立 P1）

**D1（未到货）**：PC 独立虚拟环境备好最小 `pyserial` / 官网 SDK（许可证一起保存），编写 mock serial/replay；不得在 Z19 全局 Python3.7 根环境运行 `pip install`。准备串口 JSON 帧/命令白名单和本地日志；用单元测试拒绝错误命令、重复序号、断线。

**D2~D3（到货、现场允许）**：用户安装底座、核对 12V5A、电源线、舵机与夹爪。先用厂商浏览器 Web UI 验证 HOME 附近的低速运动和小幅开合；再用电脑串口（Windows COMx / Linux `/dev/ttyUSBx`）逐步查询反馈、单关节低速小角度控制、夹爪低速开合。确认实际固件与 SDK 兼容后，固定串口通信口径。

**D3~D4**：Z19 只读检测 `lsusb` / `dmesg` / `/dev/ttyUSB*`、`cp210x` 模块、Python3.7 运行；优先移植极简 stdlib JSON + `termios`/已存在串口依赖的安全桥，不引入 PC PyTorch/ROS2。串口一次只由一个进程占用。手动断电/安全限位先于自动搬运。

## 5. SDK 使用、二次开发与许可证

- RoArm 固件仓库 README 显示 GPLv3-or-later，SDK 仓库 LICENSE 为 AGPLv3；`ros2-humble` 仓库单独检查。我们的根项目 Apache-2.0 **不能覆盖这些源文件的上游许可**。
- 首选把上游 SDK 作为**独立安装的原始依赖**而非将源码复制进根项目，并记录固定 commit/pip 版本/许可证。若需要移植 SDK 的源文件或分发其修改版本，先由队员审核 AGPL/GPL 对提交包或网络部署的责任；不要在此文档里臆断所有组合行为的法律结论。
- 固件默认保护措施、夹爪力矩上限、异常电源恢复等随不同固件版本可能改变；没有到货设备固件版本之前，不能把 GitHub main 最新实现说成我们已拥有的固件。
- 危险操作禁止自动执行：刷机/修改电机 ID、校准中位 `middle_set()`、打开力矩、载物高速运动、全臂长伸展、机械臂运动时人员手动干预。

## 6. 集成风险与决策

| 风险 | 快速检查 | 超时后的处理 |
|---|---|---|
| USB 识别失败 | 在 PC 先读型号、端口、串口反馈；再测 Z19 cp210x | PS 串口阻断先在 PC 保留实物受控示范，后续若做 R3 独立 FPGA 功能另行验证，不能阻断 PC 的 R0/R1/R2 交付 |
| SDK 版本变动 | 固定上游 commit、记录固件版本、查看实际返回字节 | 改用经测试的原生 JSON 最小指令适配，记录未兼容 API |
| 机械工作域/夹爪差异 | 低速空载、夹取轻方块、各关节角与姿态日志 | 缩小可达范围、使用固定安全工位；不直接增速或改电机 ID |
| 安全停止不确定 | 物理电源断电手段；软件 STOP/torque_off 台架测试 | 未验收的任何自动抓放程序不得无人值守 |
| ROS2/MoveIt 太重 | 初次禁装 | 保留作后续研究，使用原厂 Python/JSON 控制 |
