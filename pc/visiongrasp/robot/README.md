# Robot adapters — Issue #7

`FakeRobot` 是默认纯内存逻辑 Mock。导入模块、构造对象和查询 Fake 均不加载厂家 SDK、不打开设备。模拟阶段不声称逆运动学、碰撞安全或真实抓取成功；`RobotFeedback.end_xyz_mm` / `joint_angles_deg` 保持 `None`。

```python
from visiongrasp.contracts import ActionRequest, MOTION_STAGES
from visiongrasp.robot import FakeRobot

robot = FakeRobot(stage_delay_s=0.05)
robot.begin_run("unique-session")
for seq, stage in enumerate(MOTION_STAGES):
    result = robot.send_stage(ActionRequest(
        "unique-session", seq, stage,
        operator_confirmed=True, calibration_id="synthetic-table-example"))
    print(result.status)  # DRY_RUN; never physical success
robot.close()
```

实际 UI 还须检查视觉目标有效、新鲜、人工选定；适配器只能校验收到的 ActionRequest，不替代视觉新鲜度与标定验真。Fake 接受已标定桌面标识，但必须保持 `robot_xyz_mm=None`、`motion_allowed=False`，不把桌面坐标当基座坐标。

## API 与恢复

- `robot_source`：明确 `FAKE` 或 `ROARM_SERIAL`，连接失败不能展示为连接成功。
- `begin_run(session)`：显式建立唯一会话，序号从 0 连续递增；QUERY 消耗一个序号，但不推进运动阶段。会话不得重放。
- `validate_motion(request)`：返回拒绝原因或 `None`，不发送、不预留序号。`send_stage` 再次原子检查并在执行前预留序号。
- `send_stage(request)`：同步调用；在 UI 后台工作线程执行。运动顺序为 PREPARE→APPROACH→GRIP→LIFT→TRANSFER→RELEASE→RETURN。默认最大请求年龄 1 秒（可配置）。没有自动重试。
- `query_feedback()`：Fake 仅返回逻辑状态；实体未显式 connect 时仅返回 DISCONNECTED，不自动连接。
- `cancel_future_stages()`：可跨线程唤醒 Fake 延迟，STOP 保持直到显式 `begin_run` 建立新会话；只换 request.session 不会解除 STOP。
- 超时或故障保持锁定，需关闭并重新创建适配器、重新人工确认；close 后不能重启。实体命令发出后的 STOP 同样保持未决故障，不保证物理制停。
- `FakeRobot(stage_delay_s=..., fault_stage=Stage.LIFT, timeout_stage=..., disconnected=...)` 提供确定性故障注入。参数限速仅为 Mock 输入校验，不是实物已验限值。

## 实体边界与 SDK

`RoArmSerialRobot()` 默认未连接。只有显式 `mode="real"`、非空 `port`、当次 `onsite_confirmed=True`，再调用 `connect()` 才构造 SDK。端口在进程内独占，Windows 串口 OS 也独占打开。连接、写入或反馈故障不自动重连；close 释放资源，不关闭力矩、不回 HOME。真正授权必须由现场负责人给出，布尔参数不是现场安全的证明。

对应官方固定 SDK `d9893632aa7f5a9cb283136ab024faf3143ea7db`，型号 `roarm_m2` / `angular_direct` / 115200；来源及 AGPL 许可证见 [SDK 记录](../../../docs/vendor/ROARM_SDK.md)。本模块不复制厂家源码。

厂家 `_res` 内置重试被惰性 subclass 的单次 `_res` 替换；原 `_request_once` 不使用。每条命令最多写一次，要求完整字节计数、有限 write_timeout，避免可能无界的 flush。不使用会隐瞒错误的 gripper_angle_ctrl 包装，而使用 joint_angle_ctrl(joint=4)。SDK 把逻辑夹爪角度翻转为 wire `180-angle`，反馈已反向恢复，仅转 radians→degrees，不重复翻转。厂家 joint speed/acc 为 SDK 标度，线上分别乘 `180/2048`、`180/(254*100)`；不能称为本项目测得的物理速度。

反馈必须为新查询的 T1051，含 XYZ(mm) 与四个关节(radians)，有限数值/SDK 关节范围才可用。清空旧输入后再查询；SENT 单独记入 history，至少两条新反馈在夹爪目标 1° 内才标 FEEDBACK_CONFIRMED。这个确认仍不证明抓住物体。

**实体七阶段运动尚未开放**：固定版 `pose_ctrl(T1041)` 没有 speed/acc 参数，无法保证请求的限速，PREPARE 等笛卡尔阶段返回 `CARTESIAN_SPEED_UNVERIFIED`。因此即便提供 BenchSafety，公共七阶段入口也不能绕过第一阶段开始夹取。内部受限夹爪原语只有内存 Mock 验证，留待后续现场 R0 接口与安全方案验收；本次不提供单独真实运动 CLI。

BenchSafety 没有默认实物坐标配置。它要求现场测量的坐标边界、夹爪范围、最大 SDK speed/acc、底座固定/工位清空/断电可达/实测确认；动作还需匹配 calibration_id、新鲜反馈、人工确认及运动授权。其限制验证代码不是安全认证，桌面单应性也不能自动构成 BenchSafety。

## 复现命令（在本工作区根目录）

```powershell
conda run -n visiongrasp python -m pytest -c pc/pyproject.toml pc/tests
conda run -n visiongrasp python pc/scripts/robot_probe.py --mode mock --dry-run
```

默认输出为本工作区忽略目录 `output/pc/issue7/robot_probe.jsonl`。本脚本默认只做 Mock 七阶段；真实查询入口要同时给 `--mode real --port COMx --onsite-confirmed --confirm-query-only`，且只能在到货后当前现场批准时使用。本轮没有执行此入口。

**验收状态：PC MOCK TESTED；ROARM NOT TESTED；R0/R1/R2 NOT TESTED。** 测试用 MemoryPort 替代 serial.Serial，自动测试守卫同时禁止物理串口和相机。没有打开真实 COM 口、发送真实电机命令、刷 ESP32、加载 FPGA、安装 ROS2 或改旧八舵机代码。
