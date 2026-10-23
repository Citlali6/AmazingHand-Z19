# #33 官方运动接口与接续审核

状态：STATIC CHECKED；未打开串口、未查询实机固件、未执行运动。
固定公开源码不等于到货固件；本审核不解除 `CARTESIAN_SPEED_UNVERIFIED`。
另已读取[当前微雪产品页](https://docs.waveshare.net/RoArm-M2/)；
本轮 JSON-Control 网页读取超时，协议结论依据下列固定源码，没有用网页缺失内容推断实机能力。

| 源码与接口 | 实际读取结论 |
| --- | --- |
| [SDK generate.py](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/roarm_sdk/generate.py) | `feedback_get()`；`joint_angle_ctrl(joint,angle,speed,acc)`；`joints_angle_ctrl(angles,speed,acc)`；`pose_ctrl(pose)`，后者没有显式 speed/acc |
| [SDK common.py](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/roarm_sdk/common.py) | T105 取 XYZ mm、关节 rad；M2-S `angular_direct` 对 J4 做一次 pi−t。角度接口生成 T121/T122，speed×180/2048，acc×180/(254×100)；pose 的第四项由逻辑 deg 转 rad 并反向，生成 T1041 |
| [SDK roarm.py](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/roarm_sdk/roarm.py) | 构造即连接，原 `_res` 含重试；本项目必须沿用 single-shot 串口适配，不能新建另一 writer 或把成功写入当到位 |
| [固件 json_cmd.h](https://github.com/waveshareteam/roarm_m2/blob/c6ccc5bda2eb92df2f0850d3e63cc42b81557f4f/RoArm-M2_example/json_cmd.h) | T101 单关节 rad，T102 多关节 rad；T104 XYZT 插值，T1041 直接 XYZT，T105 反馈；T121/T122 为角度接口 |
| [固件 uart_ctrl.h](https://github.com/waveshareteam/roarm_m2/blob/c6ccc5bda2eb92df2f0850d3e63cc42b81557f4f/RoArm-M2_example/uart_ctrl.h) | T104 将 x/y/z/t/spd 传给 `RoArmM2_allPosAbsBesselCtrl`；T1041 调坐标 IK 后直接 `goalPosMove`，没有输入 speed/acc |
| [固件 module.h](https://github.com/waveshareteam/roarm_m2/blob/c6ccc5bda2eb92df2f0850d3e63cc42b81557f4f/RoArm-M2_example/RoArm-M2_module.h) | `simpleLinkageIkRad` 计算肩肘与末端缓冲角，检查 NaN；`baseCoordinateCtrl` 根据 EEMode 使用径向平面 IK；`allPosAbsBesselCtrl` 设置 goal 并调用插值。无需另发明一套 IK |

固件参考固定 `c6ccc5bd…`；SDK 固定 `d9893632…`。本轮通过 GitHub 连接读取上述固定文件，
未将第三方源码复制入本 PR，未变更依赖或构建/刷写固件。
原 #32 报告记录已安装 SDK 的固定提交，本轮没有借实例化 SDK 复核设备。

`EEMode=0` 是夹爪模式，第四轴用于夹爪开合，不能再当成独立控制任意工具姿态的腕关节。
`EEMode=1` 的末端处理不同，未经核实不能套用。S 型 0°/90°对应真实张闭及夹紧力仍按现场逐次验收。
XYZ 是厂家定义的末端参考坐标，不能未经测量当作夹爪接触点。

参考插值 `besselCtrl` 实际是半余弦进度函数；每次进度增量含 `spdInput/deltaSteps`，
循环含 2 ms delay、IK 与总线写入。`deltaSteps` 混合 XYZ 差和按 EEMode 缩放的 t 差。
因此 T104 的 `spd` 不是已经证明的 mm/s 绝对上限，也没有经现场验证的加速度界限。
其内部阻塞循环的串口反馈/STOP 可响应性也不能假定。原 SDK 小 speed/acc 经 T121/T122
缩放后与参考固件 `u16/u8` 参数存在整数截断，#31 因此使用 T101 保留非零整数参数；
不能把小数字自动解释成安全慢速，更不能为修精度改 PID/力矩。

| 路线 | 复用与限速机制 | 必须补的证据 / 故障模型 | 本轮选择 |
| --- | --- | --- | --- |
| A：实机确认支持的笛卡尔插值 | 官方 T104 内部 IK + 平滑进度；对短路径逐次审核，实测不同距离的位移/时长/加速度 | 固件版本/命令实际兼容性、真实速度界限、反馈和中断响应、IK 分支/障碍扫掠；设备可能部分移动后失败，不能重发 | 首选后续审核路线，因复用最多；目前 BLOCKED，不新增 real 发送入口 |
| B：官方模型离线 IK → 受限关节路径 | 审查并复用官方几何/偏置与 IK，逐样本做分支连续性、关节极限、路径/碰撞检查；T101/T102 的整数速度/加速度经现场验证后受控发送 | GPL 源码复用策略、模型/实机一致性、工具参考、量化、同步/段间速度、关节反馈精度和扫掠净空。端点可达不等于路径安全 | A 不具备受控证据时的备选；本轮不实现第二套 IK，不把 ROI 检查叫可达性认证 |

当前独立 `robot_base.py` 只做平面刚体变换：
`contact_xy = R(yaw) * table_xy + translation_xy`，
`contact_z = surface_z + contact_height`，
`endpoint_xyz = contact_xyz - endpoint_to_contact_base_mm`。
工具偏移只适用于配置所写的同一接近姿态；不是任意旋转的通用工具模型。
接近点加 measured clearance；将桌面最大独立误差、基座/工具/视差预算保守相加，
检查 ROI 和 XYZ 包络并为误差留边。任何缺失/不一致返回 BLOCKED，`robot_xyz_mm=None`。
即使生成 candidate，也仅 PLAN PREVIEW；真实可达性、关节与整臂碰撞尚未验证。

依赖顺序保持：#31 底座到位判据通过 → 肩/肘与夹爪闭合逐次批准 →
R1 单工位空载路径 → 轻物固定点抓放 → #10/#11 三个移动后位置 R2。
已读底座原始日志的 summary 是 exit 1、R1 false；没有把 +27.86°可见动作当到位。
目标残差约 2.14°，禁止自动补偿、重复写入或回位。

当前只有可审核动作卡的格式和顺序，没有可批准的 XYZ 数值：现场基座外参、Z、工具偏移、
净空、物块尺寸/夹取宽度、低速与反馈到位、固定点 R1 尚缺。后续每张卡必须绑定
起始反馈/本轮工位、唯一目标/幅度/方向、单次速度加速度、监控超时和人工确认；
失联/错位/障碍/目标移动/标定改变/旧帧/串口冲突/重复启动即拒绝后续动作。
分别记录 `COMMAND_SENT`、`FEEDBACK_AT_TARGET`、`OBJECT_ACTUALLY_GRASPED`，
最后一项由现场观察或视频支持；STOP 只阻止后续阶段。
