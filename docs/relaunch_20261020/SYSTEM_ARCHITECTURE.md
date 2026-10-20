# 系统技术架构 v0.2：PC 演示先完成，Z19 并行集成

> 生效日期 2026-10-20。此版本替代原 v0.1 中“必须先获 PL grant 才允许 RoArm 运动”的默认架构。**所有安全限制仍必须在 PC 端独立实施**。本文件是技术设计，新的控制代码与实物验收尚待 Codex/现场完成。

## 1. 当前首选架构（R0→R2 真实主线）

```text
            实验室 USB 摄像头（固定俯视）
                         |
                  USB → Windows PC
                         |
          OpenCV 帧读取/颜色识别/标定映射
                         |
               目标选定 + 人类确认 + UI
                         |
           PC 安全任务状态机/工作域检查
                         |
           Python 原厂 SDK（USB serial 115200）
                         |
              RoArm-M2-S 内置 ESP32
                         |
          原厂 IK/舵机内环 → 实体关节和夹爪
                         |
        真实关节反馈/动作观察 → PC UI 日志

  ALINX Z19 PS/PL：独立并行 P1，不能阻断以上链路。
```

**设计理由**：RoArm 原厂底层驱动/IK 开源、直接通过 PC USB 串口调用最快；实验室摄像头原先能在树莓派使用，不等于已通过 Z19 UVC。本期 PC 是真正负责运行视觉与机械臂的主控，直到明确验收另一种运行模式。不能把 PC 的相机和推理结果说成 Z19 板端推理。

## 2. 独立并行的 Z19（R3）路线

- **第一层：使用现有真实成果**。MJC1 R2 是 2026-10-18 在 Z19 上验证的 PS↔PL MMIO/反馈协议（`0xA0000000`，仅 R2 固件有效），但其执行对象是虚拟手，没有实体 RoArm 舵机输出。这个现成硬件演示可以独立用于展示 FPGA 通讯/状态控制的真实性，不借用来宣传“FPGA 控制过新机械臂”。
- **第二层：低成本接入**。如果有经审核的最小实现，可把 PC 任务状态送 Z19/PL 进行真实计时、状态记录、阶段校验等旁路辅助，并在 UI 单独展示“FPGA online/offline”。**故障时系统切换为安全停机/人工确认后的 PC 主线**；并行 FPGA 的异常不能自动强迫机械臂失控，也不该阻断 R2 的代码开发或演示。
- **第三层（非十天硬条件）**：Z19 PS USB 读取 RoArm，或 FPGA PL 自己实现直接 UART 通信、恢复 MIPI/控制同 bit、大规模 DPU 等，均需额外电气/驱动/时序/实机证据，不能为“提升 FPGA 核心地位”抢主线时间。

**配置区分**：旧 MJC1 R2-only 加载后替换 camera-only PL，AHIL 是另一地址/协议；新旧 bit 不可叠加。历史 `camera_hil` 实验 bit 仍 **NOT DEPLOYABLE**。部署行为由 Citlali6 另行现场批准。

**学术诚实**：`PS-only` 不是 `PL`；“有 Z19 实体板卡”不能替代 FPGA 逻辑真实运行证据；纯 PC 路径必须按实标注为“PC+ESP32 的智能抓取演示”。

## 3. PC 视觉与抓取模块合同（拟定，可单元测试）

相机输入：`camera_id, frame_seq, capture_time_monotonic, frame_width, frame_height, source='pc_uvc'`；仅使用当前会话新鲜帧，断流/旧帧不得启动新运动。分辨率首测可用 640×480 / 1280×720，按设备实际格式调整，不填保证 FPS。

标定：固定俯视相机 + 桌面 4 点或棋盘格得到像素→桌面平面的变换、机器人基座与桌面相对位置；4 DOF 无万能的任意 3D 姿态求解。目标物体的抓取高度、夹爪朝向与可达包络需以实物测量冻结，不可直接将 `(u,v)` 当作 `(x,y,z)`。

拟定数据：
```text
Detection {frame_seq, local_capture_ms, object_id, target_xy_px,
           target_xy_table_mm, calibration_id, detection_kind='HSV',
           in_safe_workspace, fresh, operator_confirmed}
ActionPlan {session, seq, stage, arm_xyz_mm, gripper_target,
            speed_limit, acceleration_limit, deadline_ms}
MotionFeedback {session, seq, source='roarm_serial', angle_or_pose,
                receive_time_ms, stable_in_tolerance, timed_out}
```
这是我们的上层契约而非微雪原厂类/API 的原名，具体字段可由 #7/#8 首轮 PR 冻结。

动作顺序：HOME/安全抬起 → 到目标上方 → 下降 → 安全夹爪闭合 → 抬起 → 投放区上方 → 释放 → HOME。先经过 PC mock/空载低速/固定点真实验收，再使用真实视觉位置。控制与视觉的对接**不包含 FPGA 前置 grant**。任何超安全范围、无标定、帧过期、反馈异常、未确认都拒绝开始新动作。

## 4. RoArm SDK 能力和限制

官方 `waveshare_roarm_sdk` 已有 `joints_angle_get()`、`feedback_get()`、`joint_angle_ctrl()`、`joints_angle_ctrl()`、`gripper_angle_ctrl()`、`pose_ctrl()` 等；串口可读反馈，HTTP 不宜作为第一版反馈来源。当前仓库记录有固定提交和许可证信息，但还没有实际第三方源码快照；由 #14 建环境、#7 做实际控制适配。

**每个实际阶段至少区分三件事**：串口成功写入、查询到厂家关节反馈、真实物体抓取成功。这三者不能互相替代。夹爪开合方向、各关节范围和实际单位必须到货后低速实测。

## 5. 安全及可恢复原则

- 机械臂固定在工作台，工作区无人手进入，旁边有可安全、迅速切断原厂独立 12V 电源的方式。厂商固件启动可能有自检/回初始姿态动作，不能假设开机不动。
- PC 任务控制器**独立**完成参数白名单、机械工作域、速度限值、运动阶段超时、取消下一阶段、真实反馈核对；无 FPGA 时也必须完整有效。
- 软件 STOP/取消是尝试停止指令/禁止新运动，不意味着已有 ESP32 动作已物理停止；`torque_set(0)` 可能致重力下垂，不能盲用。
- SDK 串口由单进程独占；掉线、重启、串口设备编号变化须锁住自动动作直到人工确认；运行脚本默认 dry-run、真实动作需当次现场批准。
- PC 已调通的安全主链不能在 Z19 实验中被覆盖。Z19 固件、驱动或 FPGA 切换需要完整 profile、bin SHA、停 DMA/卸载原驱动和回退方案；不可加载未验实验组合 bit。

## 6. 实际可展示与证据

R0：真实反馈/低速动作；R1：真固定点抓放；R2：移动方块到三个位置分别由真实新帧定位和抓取、UI/完整运行日志；R3：在独立 Z19 上展示有日志/hash 的真实 PL 功能。R3 如失败也不能虚报成功，R2 仍可按规划进行。对比赛是否满足 FPGA 赛道资格另行依据正式规则核对。

旧 `docs/design/interface.md` 的 8×SCS0009、`0x80000000` 及旧协议是历史手部方案，不能视为 RoArm ESP32 的接口。更详细的边界见 [用户确认决策](DEMO_FIRST_POLICY.md) 和 [原始官方源代码审计](ROARM_OPEN_SOURCE_AUDIT.md)。
