# 官方 RoArm SDK 固定版本与来源（Issue #14）

固定源码：[waveshareteam/waveshare_roarm_sdk](https://github.com/waveshareteam/waveshare_roarm_sdk/tree/d9893632aa7f5a9cb283136ab024faf3143ea7db)，commit `d9893632aa7f5a9cb283136ab024faf3143ea7db`。分发名 roarm_sdk，源码 __version__ 为 0.1.1；未证明 PyPI 0.1.1 wheel 与此 commit 相同，因此实际安装直接固定 Git SHA。安装的 direct_url.json 应包含这一 commit，可用 importlib.metadata 审计。

## 许可证和分发边界

- 上游 [LICENSE](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/LICENSE) 为 **GNU Affero GPL v3**；setup.py 的 MIT classifier 与 LICENSE 冲突，不采用 classifier 改授权。
- 本仓库 Apache-2.0 不覆盖 SDK。SDK 是独立安装依赖，不将第三方源码改标为本项目所有。分发 SDK/修改版本时随附原 LICENSE，并按上游许可处理源码提供义务。
- 本文是固定来源/API 审计，不是完整第三方源码 vendoring、离线包、ESP32 可复现构建或硬件验收报告。
- 固件参考 [roarm_m2](https://github.com/waveshareteam/roarm_m2/tree/c6ccc5bda2eb92df2f0850d3e63cc42b81557f4f)，保留其 GPL 相关归属。本轮不安装 Arduino 工具链、不编译或刷写固件。到货固件版本和兼容性待验证。

## 已读取的实际行为

依据固定版 [roarm.py](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/roarm_sdk/roarm.py)、[generate.py](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/roarm_sdk/generate.py) 和 [setup.py](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/setup.py)：

- `from roarm_sdk.roarm import roarm` 可仅导入；构造 `roarm(..., port=...)` 会立即打开串口。M2-S 参数为 `roarm_type='roarm_m2'`、`gripper_type='angular_direct'`、115200 baud。
- 安装时需要先有 pyserial、requests、simplejson 及 setuptools/wheel，再禁用该包构建隔离；原 setup.py 为读取元数据导入了运行模块。
- `_res` 对全部命令最多重试十次；`_request_once` 可能只返回发出的字节。部分 gripper/move_init 包装方法无条件返回 1，不能视为发送成功或到位。
- `feedback_get()` 的 M2 返回 `[x_mm,y_mm,z_mm,j1_rad,j2_rad,j3_rad,j4_rad]`；`pose_ctrl(pose)` 需要 `[x_mm,y_mm,z_mm,gripper_deg]`。角度转换和夹爪方向必须按实际 API 处理。
- 构造器只设读超时；SDK 写函数忽略短写计数。#7 必须限制单次发送、写超时、失败锁定和新反馈确认；HTTP 不用于反馈闭环。
- 默认保持 debug=False，避免在当前目录创建 python_debug.log。构造器还会配置 root logger；禁止自动创建控制器。

API 签名审计可运行 `python -m visiongrasp`，全程不实例化硬件对象。实测版本和输出见同目录的 `PC_ENVIRONMENT_VALIDATION.md`。
