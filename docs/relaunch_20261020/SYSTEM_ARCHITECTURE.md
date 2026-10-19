# 系统架构、接口和安全设计 | RoArm-M2-S × Z19

> 2026-10-20 方案 v0.1，所有新接口均为**拟定契约**，尚未实板实测；实施时保留真实证据。不得将此接口文档当作已存在代码。

## 1. PS/PL/执行机构边界

\`\`\`text
USB UVC 摄像头（固定俯视）       可选麦克风
       |                            |
  Z19 PS Linux (优先)           语音解析或UI选择
       |                            |
  图像帧/时戳/目标中心 --确认目标和抓取区域--+
       |                                    |
  桌面单应性H、置信区间、工位坐标  ---> 任务计划 (有限预定阶段)
                                                |
                                  AXI4-Lite:  request/seq/limits/heartbeat
                                                |
                             Z19 PL 任务守卫FSM，STOP latch / watchdog / grant
                                                |
                               授权结果+commit状态回PS（唯一控制进程）
                                                |
                              USB-serial 115200 → ESP32 原厂控制器
                                                |
                                  RoArm-M2-S 舵机/夹爪（12V独立供电）
                                                |
                                  串口反馈 → PS → PL状态回报、GUI日志
\`\`\`

**必须守住三个事实**：(1) ESP32 原厂负责真实伺服底层，不是 Z19 PL 直接 PWM/总线力控；(2) PL 仅通过 PS 软件桥间接授权 USB 命令，不能宣称其在电气上直接禁止 ESP32 运动；(3) 真实物理急停应为可触及的机械臂独立电源断能措施，软件 stop/torque_off 均只能作为额外安全层，需逐项实测。

### 推荐主链

- 目标从真正 UVC 帧产生；源帧须附会话标识、单调时间戳、图像序号，收到陈旧帧、相机断流或目标未确认时禁止新动作。
- PS 计算安全范围内的工位目标（机械臂基座坐标系毫米），路线为：HOME → 到物体上方 → 下降 → 闭合 → 抬升 → 到收纳区 → 释放 → HOME。各段限制速度/加速度，必要时可使用 RoArm 厂商 IK / pose_ctrl。
- Z19 PL 管理动作阶段、序号、心跳、时间限制、提交反馈、STOP 锁存；每次阶段动作前必须重新授权，失败不得发送串口运动指令。
- RoArm USB 主控为独立 12V 电源，USB 不承担舵机电源。选择 USB 串口（反馈可靠性需测），不把 HTTP 控制 ACK 当成执行完成反馈。
- PC 可以充当视频源/操作 UI，但最终每次动作必须经 Z19 PS→PL 守卫。PC 直接驱动 RoArm 只允许 D1-D2 **台架 bring-up**，不能替代最终演示的 FPGA 路径。

## 2. 硬件 profile 选择

**路线 A（优先）**：Z19 Linux \`/dev/videoX\` USB UVC 采集 + 独立已验证 MJC1 R2 PL profile + \`/dev/ttyUSBX\` RoArm 串口。注意：UVC、CP210x、USB Host 驱动、Python3.7/Opencv3.4、端口并发均未经过本机测试；仅硬件架构可行。

**路线 B（快速保底）**：PC USB 视频采集+HSV/标定 → 有序网络消息到 Z19 PS → PL 动作守卫 → PS串口→机械臂；不需要让相机 PL 与 HIL 同时运行。必须明确展板/报告的视觉在 PC，而非板端。可后续切回路线 A，不得把 A 当成默认已调通。

**禁止**：未经排查直接加载老 \`camera_hil\` 诊断 bit；原相机-only 与原 MJC1-only profile 不能叠加，载入其一将替换整个 PL；原 MJC1 R2 地址 \`0xA0000000\` 与 AHIL \`0xA1000000\` 不可混用。MJC1 R2 不能无源修改就当作 RoArm 完整闭环；其 MCU/执行路径适配须在新工作分支和独立二进制产物上完成。

## 3. PS ↔ PL 的最小协议草案（待控制负责人审查冻结）

建议保留 MJC1 原 MMIO 原语与经过验证的序号/commit/ACK机制，**先审查原 \`fpga/mjc1_fpd/\`、\`fpga/hand_control/\`、\`docs/design/interface.md\` 的真实实现**。不能凭本文杜撰“现有寄存器已支持 grant”。

\`\`\`text
ActionRequest = {
  session_id: uint64, seq: uint32, stage: enum,
  target_xyz_mm: [x,y,z], gripper_angle_deg, speed, acc,
  source_frame_seq, source_capture_mono_ms,
  target_validated: bool, operator_confirmed: bool
}
ActionDecision = {
  session_id, seq, state, grant/deny, deny_reason,
  watchdog_ok, stop_latched, pl_commit_seq
}
ArmFeedback = {
  session_id, seq, monotonic_time, joint_angles,
  end_xyz_mm, grasp_feedback_kind, comm_status,
  stage_complete_observed: bool
}
\`\`\`

这是**逻辑消息接口草案**，不是强制所有字段写在一个 AXI 寄存器，也不是 MCU SDK 已实现字段。PL RTL 可用少数 stage/seq/TTL/stop 寄存器，不承担字符串 JSON、YOLO 或逆运动学。具体 MMIO 地址/32bit 拆分在代码审查后冻结、用 tests 验证，且必须区分老 MJC1 profile 与新 RoArm profile。

严谨约束：

1. 一个串口唯一写入者；PC/网页/SDK/SSH 不能并行发控制命令；锁持有者丢失/重启必须产生新 session。
2. 计划动作先检查笛卡尔安全工作域、速度/角度限制、触发者确认及最新帧，才允许向 PL 提交。
3. PS 只对匹配 session+seq+stage 的 PL grant 发送**一次**动作，重放/时间过期拒绝；发送串口指令≠机械臂已完成动作。
4. 机械臂真实反馈到达并符合容差、超时约束，才进入下一状态；原厂反馈是关节位置/末端坐标，**没有证明力传感器/负载检测**。对“抓取成功”需用视觉/人工观察和物体移动证据，不凭夹爪角度臆断抓牢。
5. STOP / 断链 / 超时后 PL 锁存拒绝新的运动请求；PS 最多尝试厂商支持且经实测有效的停止/关扭矩命令，**不保证物理即时制停**；现场操作员能直接断开 12V 执行电源。软件复位只允许人工确认机械臂安全后操作。
6. 接入麦克风必须复用语音白名单、reject/STOP 语义，语音高置信度本身不等于动作授权。

## 4. 视觉与标定

固定俯视相机（优先桌面独立支架），将工作平面限定为单一高度。先用 OpenCV 基本库完成 HSV 彩色块分割 / 轮廓重心、背景/颜色否定样本；图像结果声明 **规则检测**，不能包装成 YOLO 准确率。用桌面棋盘/四角标定点求像素到桌面坐标的单应性矩阵，再测基座相对桌面坐标变换。单应性仅适用于平面，目标顶面高度/夹爪抓取高度按实物标定的尺寸表限定；不能将任意 RGB bbox 直接视作三维坐标。

建议帧处理输出：
\`\`\`text
vision/1 {camera_session, frame_seq, capture_mono_ms,
  object_id, class_name, source='hsv'|'ncnn',
  pixel_center, table_xy_mm, coordinate_frame,
  confidence_or_rule_score, calibrated, stale}
\`\`\`
有效期建议从配置开始设定，例如源帧不超过 500ms/结果不超过 1200ms，仅作为初始严格策略，需按实际处理链路量测调整，不是原 camera 800/1600ms 契约“自动迁移”。不可为报出漂亮 FPS 直接放宽过期策略；跨机器 PC ↔ Z19 时用新鲜接收单调时间及 session/seq 判重，不依赖不同机器的绝对 monotonic 数值可比较。最终如启用 NCNN，必须有新 USB 相机的同图基准/类别正负样本重新验收。

## 5. 运动策略与简单可复现环境

- 最先只支持 1~2 类**轻质、不尖锐、不易碎**演示物；记录物品尺寸与质量、可达位置、抓取方式和放置工位，不尝试随机散乱堆叠或遮挡对象。
- 机械臂固定在稳定工作台且夹具拧紧，桌面留安全边界和手动断电通道；先测 HOME、抬升高度、机械限位、下探区域，任何未知位置不可盲动。
- 使用厂家 IK 接口 \`pose_ctrl()\` 或预定姿态插值；不能直接将 PC 相机像素传给关节驱动。
- 仅在逐项低速台架验证后开启自动多阶段；每次运动需独立反馈/观察超时。禁止动作过程中有人手伸入工作区。

## 6. 需要测量的 FPGA 价值

- 有 PL grant 的合法阶段成功数 vs 不合法/重复/过期阶段被拒绝数；
- STOP/heartbeat 断链到“PS 不再发出新的运动指令”延迟分布（注意不等于物理臂停止）；
- FPGA FSM 的动作状态、错误码、ACK 时序，与 host-only 安全逻辑对照（如果测得才能讨论差异）；
- 合成/实现资源 LUT/FF/BRAM、时序 WNS/WHS、CDC/DRC、使用的 Vivado 2020.1 版本、真实 bin hash；在新配置实际上板前不能以老配置报告代替；
- 端到端目标感知→抓取放置耗时、同目标多轮成功率和失败分析。

## 7. 旧代码复用映射

| 原成果 | 复用方式 | 防误用规则 |
|---|---|---|
| \`fpga/mjc1_fpd/\` | 真实 PS/PL 寄存器、序号和 ACK 的首选模板 | R2 bit 不直接宣称 RoArm/相机组合已验收 |
| \`fpga/hand_control/\` | STOP、watchdog、AXI 设计候选、XSim TB | 旧 AHIL 地址和八舵机控制语义不能直接适配 JSON |
| \`host/app/control/\` | 控制后端抽象与协议测试模式 | SCS 协议不等于 RoArm 的 ESP32 JSON 协议 |
| \`host/camera_linux/\` | 已有 JPEG 同帧绑定、性能诊断与断流处理 | IMX214 DMA 驱动不能用于 UVC 的 /dev/video |
| \`host/app/vision/\` | 图像输入抽象/视觉接口 | 新 HSV/USB 源须显式命名和回归 |
| \`host/app/voice/\` | 中文指令解析/安全白名单 | 未经实测不能直接发真实动作 |
| \`sim/\` | 原系统演示对照、回归测试 | 旧八执行器手模型不得自称 RoArm 仿真 |
| \`docs/migration/\` | 历史结果、未合并 PR 和工作区快照依据 | 归档代码不得无审查全量移植 |

本文接口为讨论基线；Codex 第一轮需提交“现有代码接口→最小新接口”的映射表，经负责人确认后才能冻结 ABI 或上板。
