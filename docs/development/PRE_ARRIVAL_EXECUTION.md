# 机械臂到货前：Codex 开发启动令（2026-10-20）

> **唯一仓库**：`Citlali6/VisionGrasp-Z19`。**交付原则**：Demo-first，先 Windows PC + 已确认可显示画面的 USB 摄像头 + 微雪 RoArm-M2-S 原厂 ESP32/Python SDK。Z19/PL 独立 P1，不阻塞 PC 视觉与真抓放。用户已经拿到板上丝印 `SIM1319-HD720P` 的实验室 USB 摄像头，并确认 **Windows 相机可以显示画面**；OpenCV/帧率/畸变/标定仍未实测。机械臂已经下单，**尚未到货**。以下是操作和代码的准备任务，不是硬件验收。

> **开发机环境更新（用户已确认使用 Anaconda）：** Windows 主开发环境统一为独立 Conda 环境 `visiongrasp`（Python 3.10）。**不要强制另外创建 venv**；先阅读 [Windows Anaconda 环境安装与摄像头自检](ANACONDA_SETUP_WINDOWS.md)。#14 负责落实 `pc/environment.yml` 或等价可复现配置，测试依赖仍必须与 `pc/pyproject.toml` 分工清楚。

## A. 阶段任务图：并行但不互踩

| 顺序 | GitHub Issue | Codex 工作包 | 独占目录与产物 | 不依赖什么 |
|---|---|---|---|---|
| 第 1 波，可现在开工 | [#14](https://github.com/Citlali6/VisionGrasp-Z19/issues/14) | 官方 SDK 真源码、固定版本、Windows PC 虚拟环境和离线导入/许可核验 | `pc/pyproject.toml` 或 `pc/requirements*.txt`（二选一）、`pc/README.md`、`docs/vendor/` | 机械臂到货、ROS2、FPGA |
| 第 1 波，可现在开工 | [#8](https://github.com/Citlali6/VisionGrasp-Z19/issues/8) | PC 真 USB 摄像头采集、HSV 色块检测、标定工位与可视化诊断 | `pc/visiongrasp/vision/`、`pc/tests/test_vision*.py`、`pc/scripts/camera_probe.py` | 机械臂到货、Z19 UVC、PL |
| 第 1 波，可现在开工 | [#7](https://github.com/Citlali6/VisionGrasp-Z19/issues/7) | RoArm SDK 安全适配器、纯离线 Fake、动作阶段/错误处理 | `pc/visiongrasp/robot/`、`pc/tests/test_robot*.py`、`pc/scripts/robot_probe.py` | 机械臂到货、Z19；外部依赖锁以 #14 为准 |
| 第二波，契约稳定后 | [#18](https://github.com/Citlali6/VisionGrasp-Z19/issues/18) | Mock 端到端模拟、PC 启动入口、最小 GUI、日志/交互 | `pc/visiongrasp/app/`、`pc/tests/test_app*.py`、`pc/scripts/demo.py` | FPGA、真实机器人 |
| 到货后**现场批准才动** | [#10](https://github.com/Citlali6/VisionGrasp-Z19/issues/10) + [#11](https://github.com/Citlali6/VisionGrasp-Z19/issues/11) | PC 真机 R0→R1→R2，三位置抓放、安全与报告 | 本轮独立 PR 与带日期测试记录 | Z19/FPGA |
| 独立低优先级 | [#9](https://github.com/Citlali6/VisionGrasp-Z19/issues/9) | 复用原 PL 硬件已验证成果，争取展示但不能延误核心作品 | 原 FPGA 相关目录/独立实验 | P0 主线 |

**特别注意**：仓库已存在 `host/app/control/backend_serial.py`，那是旧灵巧手 SCS/1Mbps 半双工控制；`host/app/main.py` 是旧“香蕉/ArUco/模拟手”状态机；仓库根 `requirements.txt` 混合了旧 Z19、NCNN、Vosk、MuJoCo 等较重依赖。**本期禁止直接改用旧后端或 `pip install -r requirements.txt` 当作 Windows RoArm 安装步骤。** 新 PC 软件单独放 `pc/`，保留历史源码完整不动。

## B. 官方上游精确版本与实核结论

| 官方资产 | 已核对提交 | 适用与注意 |
|---|---|---|
| [`waveshareteam/waveshare_roarm_sdk`](https://github.com/waveshareteam/waveshare_roarm_sdk) | `d9893632aa7f5a9cb283136ab024faf3143ea7db` | RoArm-M2-S 选 `roarm_type='roarm_m2'`，`gripper_type='angular_direct'`；USB serial 115200，`pyserial`/ `requests`；PyPI README 展示 `roarm-sdk==0.1.1`，仍应校验下载版本与固定源码一致性 |
| [`waveshareteam/roarm_m2`](https://github.com/waveshareteam/roarm_m2) | `c6ccc5bda2eb92df2f0850d3e63cc42b81557f4f` | 公开 ESP32 固件、JSON/UART/Web/原厂 Python 示例；并不意味着已复现整套构建或与到货出厂固件二进制一致 |
| [`waveshareteam/roarm_ws_em0`](https://github.com/waveshareteam/roarm_ws_em0) | `f06b2ed6c1ddc5b7690975fdbba84aab626a2229`（`ros2-humble`） | ROS2 非本轮前置，不引入 ROS2 环境/大体积模型 |

官方文档：
- [RoArm-M2 官方上电/开箱](https://docs.waveshare.net/RoArm-M2/Preparation-Before-Use/)
- [RoArm-M2 快速上手](https://docs.waveshare.net/RoArm-M2/Getting-Started-Quickly/)
- [Python SDK 源码](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/roarm_sdk/roarm.py)
- [中文 API](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/doc/roarm_m2_zh.md)
- [JSON 控制教程](https://docs.waveshare.net/RoArm-M2/JSON-Control/)

**重要的源码行为**（已阅读而非猜测）：官方 `roarm.py` 打开串口时构造器会真实打开端口；`_res` 存在最多 10 次重试，`_request_once` 把串口命令写入后通常直接返回已发送的字节而非运动完成反馈，失败可能返回 `-1`，不是只抛异常。**因此不能把“调用成功/有返回”当作运动到位；也不能在我们的上层对运动命令再叠加无条件重试**。#7 必须审计此行为并严格限制真实硬件入口，避免重复触发。HTTP 模式主要用于写入，不应替代串口反馈。

**许可证**：SDK GitHub `LICENSE` 为 AGPL-3.0（部分 `setup.py` 分类字段写 MIT，不能据此改授权）；固件为 GPL-3.0-or-later 声明。优先将官方 SDK 作为单独锁定的第三方安装依赖；是否 vendoring 源码、所需许可证/NOTICE、编译环境和实际源快照完整性均须列明。只有链接/版本审计 ≠ 完整源码备份 ≠ 可复现固件构建 ≠ 已经跑过机械臂。

## C. 唯一 PC 包结构与所有权（推荐，不允许四名 Codex 任意开新架构）

```text
VisionGrasp-Z19/
  pc/
    README.md                   # #14 主笔：Windows Conda Python 3.10 环境，安装步骤与 mock 命令
    pyproject.toml              # #14 主笔：PC 最小依赖与可编辑安装；不要改根 requirements
    visiongrasp/
      __init__.py               # #14 建骨架；#7/#8 避免互改
      contracts.py              # 本启动令里定义的冻结字段，由 #14 建骨架
      robot/                    # #7 ONLY
      vision/                   # #8 ONLY
      app/                      # #18 ONLY
    scripts/
      robot_probe.py            # #7；默认 dry-run/mock
      camera_probe.py           # #8；Windows 实相机需要本人现场运行
      demo.py                   # #18；Mock 开箱可运行
    tests/
      test_robot_*.py           # #7 ONLY
      test_vision_*.py          # #8 ONLY
      test_app_*.py             # #18 ONLY
  docs/
    vendor/                     # #14 上游 SHA/许可证/依赖与校验
    development/                # 该任务令与接口约定
```

如 #14 先建立包结构，#7/#8 在 main 尚未合并 #14 前可使用各自分支局部 mock + 提供路径兼容的 PR，**不要自己改 `pc/pyproject.toml` 或抢改 `pc/visiongrasp/contracts.py`**；Codex 必须在 Issue 中标明依赖的 PR/commit，严格按合并顺序重取最新 main、开新分支或依据任务授权同步变更。已有未提交工作要停下来报告，不做 reset/clean/rebase-force。

## D. 阶段共享接口（预冻结 v0.1）

参考 [接口契约](PC_MVP_CONTRACT.md)，要求至少有：
- `VisionTarget`：帧来源、实际帧序号、同机 monotonic 时间戳、像素中心、桌面坐标（未标定时为 `None`）、相机/标定版本、有效与否、原因；**坐标单位在字段名里体现**。
- `RobotFeedback`：来源为 Mock 或实际串口、单调接收时刻、关节角度、末端 XYZ、通讯/解析状态；缺字段就用 `None`，绝不填假的零值。
- `ActionRequest`：动作种类、目标 XYZ（mm）、夹爪目标/速度等安全约束、用户已确认状态、动作序号；先做纯 mock，在实体上需要实际标定后冻结数值。
- `SystemStatus`：CAMERA_OK/NO_FRAME/UNCALIBRATED、ROBOT_MOCK/ROBOT_CONNECTED/FAULT、IDLE/RUNNING/STOP_REQUESTED/FAULT。STOP 只保证**不再启动新阶段**，不得承诺物理急停。

为避免 SDK 与视觉线程抢控制权，**只有机器人适配进程/控制器持有 serial**；前端不能直接实例化第二个 SDK 对象；摄像头不能在两个进程同时被独占；UI 对真人动作必须有明确“人工确认”流程。

## E. 到货前实际可做与不可做

**可做**：
1. Windows 环境隔离、包安装/依赖锁、SDK 导入检查、API 合规审计与 LICENSE 保存；
2. Mock RoArm 的关节/位姿/夹爪状态与动作事件，按有限状态机模拟安全阶段；
3. OpenCV 对实验室 `SIM1319-HD720P` 摄像头实时显示、HSV 高对比目标框、空桌/误检测试，记录 Windows 相机 API 与实际分辨率；
4. 用打印标定板/棋盘或 4 个已知桌面点完成**相机像素→桌面平面(mm)** 变换；注意机器人基座坐标尚未到货，**不可冒充真实机械臂坐标转换已完成**；
5. Mock 全流程 UI：取真实摄像头 → 规则检测 → 生成候选坐标 → 用户确认 → Mock 轨迹/反馈 → 任务日志，演示“系统准备完成”但不能称实体抓取。

**禁止**：Codex 擅自使用真实串口发运动、硬编码机器姿态后自动运行、调用 `move_init`、`middle_set`、`torque_set(0)` 作为自动安全措施、刷 ESP32、改电机 ID、修改 Z19 bit/系统镜像、让 FPGA 阻挡 PC demo、ROS2/YOLO 新模型训练、远程操纵真实设备。实物上电必须 Citlali6 现场同意、底座固定、运动区空旷、可安全独立切断 12V。

## F. 到货前交付门槛（Codex 每个 PR 必填）

- 写明源自 `Citlali6/VisionGrasp-Z19` 最新 main 的分支名/commit、Git diff 摘要、改变路径、运行命令与真实 exit code、Windows Python 版本。
- 分开报告 `STATIC CHECKED`（仅代码静态）、`MOCK TESTED`（伪设备）、`PC CAMERA TESTED`（人现场执行并提交帧/运行日志）、`ROARM TESTED`（到货后真实设备）；未实际运行的测试必须标 NOT VERIFIED。
- 最低自动化：包可导入、假设备反馈/错误、工作域和阶段限制、空场/断流/过期帧、标定单元测试；**代码测试不得自动打开 COM 口或移动电机**。
- 每个 PR 都必须包含简洁的复现说明、已发现的错误、受控恢复措施，不把计划写成通过，不推到 `main`，不自动合并。
- 不上传人脸/隐私帧、访问令牌、串口设备私有日志/不必要大文件；如需示例图，用自己合成的色块测试图或经过同意、去隐私的素材。
- 旧 `host/` 和 `fpga/` 尽量只读；`docs/voice/`、`sim/` 等先不改动。

## G. 在 PC 真机到货前的最低“开箱可演示”状态

`#14` 的 Windows Conda 环境可按文档独立建立并完成包安装；`#7` 的 fake 可模拟状态/非法动作/断线；`#8` 的真实摄像头能显示方块检测框和桌面坐标/未标定提示；`#18` 的 `--mode mock` 可串起 UI、真摄像头与 fake 机械臂，**完全不依赖硬件和 Z19**。最终由 Citlali6 实测并认可，再切实体 R0→R1→R2。
