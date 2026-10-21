# VisionGrasp PC（机械臂到货前）

Windows + Anaconda + Python 3.10，CPU 即可。不安装仓库根 requirements，不复用 base 或旧 yolo 环境。

## 安装（Anaconda Prompt，仓库根目录）

```bat
conda env list
conda env create -f pc/environment.yml
conda activate visiongrasp
python -m pip install --no-build-isolation -r pc/sdk-requirements.txt
python -m pip install --no-deps --no-build-isolation -e pc
python -m pip check
python -m visiongrasp
python -m pytest pc/tests
```

已有同名环境先保留，不运行覆盖、`--prune` 或全局安装。本项目不另建 venv。PowerShell 不认 conda activate 时用 Anaconda Prompt 或 `conda run -n visiongrasp ...`，不修改全局 PATH。

**安装分两步是必要的**：官方 SDK 的 setup.py 会导入 serial/requests；默认隔离构建会出现 `ModuleNotFoundError: serial`。环境文件先安装锁定的运行和构建依赖，再使用 `--no-build-isolation` 安装固定 SHA 的 SDK。不因此改用未经审计的新版本。

环境文件锁定本机验证的 Python/pip 及 pip 依赖；pyproject 定义项目元数据和兼容约束。SDK 单独固定在 sdk-requirements，版本号 0.1.1 不代表它等同 PyPI 同名包。初次安装需要访问 Conda/PyPI/GitHub；当前交付不含完整离线安装包。

## 离线测试与目录

`python -m visiongrasp` 只导入并检查 SDK 签名，不构造 SDK 控制器。测试默认拦截串口打开和摄像头访问，不需要机械臂、相机或 FPGA。

并行工作树使用自己的源码目录运行测试；脚本优先导入所在工作树的 `pc/`。不要在各个工作树之间反复安装 editable 包覆盖公共环境。环境依赖由 #14 统一维护。

日志、测试产物、下载和临时诊断统一放在工作区 `output/pc/`，不加入 Git，不向 F 盘根目录散放文件。Conda 环境和缓存由现有 Conda 目录管理。

## 接口与状态

共享模型见 `visiongrasp/contracts.py`，语义依据 [PC 契约](../docs/development/PC_MVP_CONTRACT.md)。FramePacket 带实际 BGR、来源、会话、序号和单调时刻；有效 VisionTarget 必须包含桌面毫米坐标及标定版本。ActionRequest 的创建时刻和超时用于拒绝旧请求；机器人真实坐标不可用时保持 None。

仅合法枚举、有限数值、明确单位和已知状态才能越过模块边界。Mock 的 DRY_RUN 不是物理抓取成功，SENT 不是 FEEDBACK_CONFIRMED。后续 robot、vision、app 模块分别归 #7/#8/#18。

## 第三方与硬件边界

[SDK 来源、许可证与审计](../docs/vendor/ROARM_SDK.md)。SDK 构造器会打开串口，禁止将构造器放进自动测试或默认启动路径。到货前不调用实际运动、刷机或 FPGA 加载；真实 USB 摄像头由负责人现场选择和验证。

本轮可以报告 Windows 依赖与 MOCK TESTED；真实相机、RoArm 和 R2 抓放均须各自实测后才能改状态。
