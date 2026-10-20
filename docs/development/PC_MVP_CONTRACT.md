# VisionGrasp PC MVP v0.1 接口契约（Codex 并行协作基准）

> 2026-10-20 冻结**概念/字段/单位**，不声称代码已经存在。由 #14 建立 `pc/visiongrasp/contracts.py` 最小实现；#7/#8/#18 必须遵守语义。修改契约需在相关 Issues / PR 里通知两位队友，并提交兼容性测试；不得将旧 AmazingHand 八舵机接口或相机 MIPI ioctl 作为该接口默认实现。

## 1. 统一的坐标、时间、来源规范

- 摄像头像素 `px`：原点为图像左上角，`u` 向右，`v` 向下；只对应当前摄像头参数和帧尺寸，旋转/裁剪后需新版本。
- 桌面世界坐标 `table_xy_mm`：选定桌面 2D 原点、X/Y 方向和已知距离（mm）；平面单应性从同一实际工作台标定得到。**单应性不能估计目标实际 Z，高度应另外按物品类别/现场测量设定。**
- 机械臂 `robot_xyz_mm`：以 RoArm 基座厂商定义的坐标系为准；到货前一律 `None` / `UNCALIBRATED`，不填伪造的机械臂坐标。
- 时戳使用**同一进程的 `time.monotonic()`（秒）**，日志另外记录 `datetime` 供人阅读；跨进程/跨设备传递时必须携带会话 ID、接收时刻和序号，不得直接比不同设备 monotonic 值。相机旧帧拒绝时间阈值为可配置参数，默认阈值仅为起步值、不当成最终性能。
- `source` 必须明确 `LIVE_PC_UVC`、`IMAGE_TEST`、`SYNTHETIC`；`robot_source` 必须明确 `FAKE`、`ROARM_SERIAL`、`UNKNOWN`。真实视频 + Fake 机械臂的演示只能标 `PC CAMERA + MOCK ROBOT`，不可称真抓放。

## 2. 数据模型（冻结字段语义，不锁死 Python 类实现细节）

```text
VisionTarget:
  camera_session: str
  frame_id: int                  # 单 session 内递增
  capture_monotonic_s: float
  source: enum                   # LIVE_PC_UVC | IMAGE_TEST | SYNTHETIC
  frame_wh_px: tuple[int,int]
  object_label: str              # 例: red_block
  center_uv_px: tuple[float,float]
  table_xy_mm: tuple[float,float] | None
  calibration_id: str | None
  valid: bool
  rejected_reason: str | None   # NO_OBJECT | STALE | UNCALIBRATED | OUT_OF_WORKSPACE
  confidence_or_rule_score: float | None

RobotFeedback:
  robot_source: enum             # FAKE | ROARM_SERIAL | UNKNOWN
  received_monotonic_s: float
  joint_angles_deg: tuple[float,...] | None
  end_xyz_mm: tuple[float,float,float] | None
  communication_ok: bool
  raw_feedback_summary: str | None # 只放脱敏摘要
  error: str | None

ActionRequest:
  run_session: str
  sequence: int
  stage: enum                    # QUERY | PREPARE | APPROACH | GRIP | LIFT | TRANSFER | RELEASE | RETURN
  robot_xyz_mm: tuple[float,float,float] | None
  gripper_target_deg: float | None
  speed_setting: float | None
  acceleration_setting: float | None
  operator_confirmed: bool
  calibration_id: str | None
  motion_allowed: bool           # 真机必须由运行模式与安全检查共同批准

StageResult:
  run_session: str
  sequence: int
  stage: str
  status: enum                   # DRY_RUN | SENT | FEEDBACK_CONFIRMED | TIMED_OUT | REJECTED | FAULT
  started_monotonic_s: float
  completed_monotonic_s: float | None
  error: str | None
```

字段名可以按 PEP8 增加细化，但 `mm / px / s / deg` 单位、空值、错误含义和前端/后端归属不能被悄然改写。绝不把关节 radians 当 degree，也不要将末端 `pose_ctrl` 的腕关节方向和夹爪开合角当一个自由度。

## 3. Robot 适配器 v0.1（逻辑方法名，不是微雪原厂 API）

```python
# 概念 API：由 #7 实际实现，不代表这段函数已经存在
class RobotAdapter:
    def query_feedback(self): ...
    def validate_motion(self, request): ...
    def send_stage(self, request): ...
    def cancel_future_stages(self): ...
    def close(self): ...
```

建议拆分：
- `FakeRobot`：纯内存确定性状态，能注入错误、延迟、断线；默认唯一可启动模式，不加载厂家 SDK、不打开 COM 口；
- `RoArmSerialRobot`：明确提供 `--port COMx` 等配置，只有`--mode real` 且用户现场确认后才连接串口，更严门槛才会发送真正运动；查询反馈也是“物理实测”，不能在无设备时自动调用；
- 任何 SDK 原始 `None`、`-1`、解析错误必须映射为失败而不是“成功”；对已发送的运动请求没有经过安全评估不得自动重发。原厂 SDK 可能内部重试，先理解其实际行为并记录风险；
- `stop_request` 至少能停止**尚未发出的下一个阶段**；不能保证当前固件即时制停，**不在缺乏测试时用 `torque_set(0)` 作为默认停止**；
- 真实运动必须先检查人工确认、机械可达区域（现场实测配置）、速度/加速度限制、机器人状态、目标坐标/标定版本有效、串口独占、紧急电源可用；
- 到货前缺失真实工作域配置时，`real` 动作模式必须 fail-closed，不能把测试时例的虚假坐标当成真实安全范围。

## 4. Camera/Visual 适配器 v0.1

- `CameraProvider.read_latest()` 返回真实 BGR 帧与来源/时戳/帧序号；不会仅给 `np.ndarray` 而丢掉帧新鲜度信息；
- `BlockDetector.detect(frame)` 使用 HSV/面积阈值/轮廓规则，不依赖训练模型；空白帧/错色/半遮挡要返回无有效目标；
- `TableCalibrator.project(center_uv_px)` 在完成经验证的相机→桌面二维单应性后输出毫米，没完成返回 `None` 并明确 `UNCALIBRATED`；
- 相机端口与后端可配置（Windows `cv2.CAP_DSHOW` 或 `cv2.CAP_MSMF` 可尝试，但需以实测为准），不要写死 index=0；帧率/分辨率实际值必须读取而非盲信设定值；
- 设备热插拔、摄像头被其他程序占用、无法打开、黑屏、重复旧帧时应有错误反馈，不应产生“合法目标”。

## 5. PC 应用最小 UI、状态、安全

- 模式显示始终真实：`LIVE CAMERA / IMAGE TEST` 和 `FAKE ROBOT / REAL ROBOT` 各自独立；没有任何 USB 机械臂也能运行 Fake UI；
- UI 不应直接发机械臂 SDK 命令，应经任务控制器创建和审查 `ActionRequest`；
- 操作流程：获取实时画面→检测候选→标定（如有）→人工点击确认→任务阶段日志→Mock反馈；真实运动模式另需硬件现场安全闸门。
- `STOP`、断流、未标定、无目标、不确认、机器人通信故障、动作过时均不得启动新动作；避免“按钮点两次”产生重复命令。
- **Mock 模式不是运动学模拟**：可用简化动画/状态图演示执行顺序，但不得宣称真实运动轨迹或物理安全性能。

## 6. 测试契约

- `test_contracts`：字段/单位、合法/非法枚举、空值与状态转换；
- `test_robot_fake`：无机械臂可运行，非法目标/旧请求/未确认/超限拒绝，断线/超时/STOP 退出安全；
- `test_vision`：无现场相机也能用程序合成颜色形状/棋盘点，红蓝检出、错误颜色/空帧否定、单应性已知点误差；
- `test_app_mock`：无机器人/无摄像头时 Fake + synthetic 两层明确标识，流程能够输出可分析的任务日志。不能因假设备都存在就显示“ROARM CONNECTED”或“Z19 PL ONLINE”；
- 所有 Python 测试用 `pytest`、Windows 隔离 PC 环境执行，覆盖失败用例和退出码；不运行任何真实 COM 口/USB 命令，CI 也不需要接硬件；
- 有实体设备后分别补 `PC CAMERA TESTED`、`ROARM TESTED`、`R1 TESTED`、`R2 E2E TESTED`，无法用 mock 测试代替。

## 7. 文件冲突与改契约流程

`#14` 首先在新 `pc/` 包创建本契约代码入口（或选择 `dataclass`/Protocol 的最小实现）。`#7`、`#8` 只修改其拥有子目录/单测，绝不“帮忙顺手”改 `AGENTS.md`、`host/app/main.py` 或 `pc/pyproject.toml`。如需更改共享字段，先在负责 Issue 评论中提出，负责人批准后由契约 owner 单独修改，其他 Codex 同步 rebase/merge **须遵循现行仓库 Git 规则**，禁止强推。
