# Windows + Anaconda：VisionGrasp-Z19 前期环境安装指南

> **适用范围**：2026-10-20、机械臂尚未到货的 PC 开发阶段。负责人目前使用 **Anaconda**；实验室 USB 摄像头 `SIM1319-HD720P` 已在 Windows 自带相机应用看到画面，尚未通过 OpenCV 证明其真实 FPS、分辨率或标定精度。**官方 RoArm SDK 在真实到货 ESP32 上的兼容性也尚未验证。** 本页是准备说明，不是安装/硬件实测报告。

## 1. 必需与暂不安装

| 软件 | 必要性 | 原因 |
|---|---|---|
| Anaconda / Miniconda | **已有 Anaconda，不重装** | 管理 Python 版本和隔离环境 |
| Git for Windows | 必需，已安装则跳过 | clone、分支、Codex PR、安装基于 Git SHA 的依赖 |
| VS Code + Python/Pylance 插件 | 推荐（已有则跳过） | Windows 调试、选择解释器、打开本仓库 |
| Conda `visiongrasp` (Python 3.10) | **建议新建** | `numpy`、OpenCV、微雪 SDK、pytest |
| OpenCV、NumPy、pyserial、requests、pytest、RoArm SDK | Conda 环境内 Python 包 | 实时视频/标定、串口控制（到货后）、离线测试 |
| Arduino IDE、USB-UART 厂商驱动 | **现在不用预装** | 原厂固件无需提前刷写；机械臂到货后先检查设备管理器枚举，驱动需求按实际 USB 桥芯片决定 |
| Vivado/Vitis、ROS2、CUDA、PyTorch、YOLO、JupyterLab | **PC Demo 暂不需要新增安装** | Z19/PL 另行 P1，ROS2 与训练模型不在第一阶段 |

不要给现有 `base` 环境安装一堆包；不要删掉旧 conda 环境。**本项目使用独立 `visiongrasp`，不再要求再建一套 Python `venv`。** Anaconda 环境仍可用 `python -m pip` 安装 PyPI/官方 SDK。

## 2. 一次性准备：Anaconda Prompt（Windows）

请在 Windows **Anaconda Prompt** 中执行；不需要管理员权限。已经有 `visiongrasp` 环境时先用 `conda env list` 检查，不要执行会覆盖它的命令。

```bat
conda --version
git --version
conda env list
conda create -n visiongrasp python=3.10 pip -y
conda activate visiongrasp
python --version
python -m pip --version
python -m pip install --upgrade pip
```

**建议起始依赖（仍需 Codex #14 核验最终可复现 lock 文件）**：

```bat
python -m pip install "numpy==1.26.4" "opencv-python==4.10.0.84" "pyserial==3.5" "requests" "pytest" "roarm-sdk==0.1.1"
```

依赖选型说明：`roarm-sdk==0.1.1` 来自微雪官方 Python SDK README，但这**不是**固定 Git commit 自动等价验证；#14 要核对发布包 API/许可证/源码版本与项目所锁依赖。官方 SDK `setup.py` 引入 `pyserial`、`requests`，Python≥3.10 还可能需要 `simplejson`，由包安装解析；如有安装失败请保留完整报错，不改装全局 `base`，也不直接 `pip install` 一个新的未经审计版本。

如果 Windows 里安装了多个 Python，请尽量使用 `python -m pip` 而非裸 `pip`。**Conda 负责隔离 Python，本教程只通过该环境内 pip 安装 PyPI 包**，尽量避免在同一个新环境混用 conda/pip 对 OpenCV/NumPy 的二进制构建。

## 3. 最小检查：无需机械臂、不打开串口

在 **已激活 `visiongrasp`** 的 Anaconda Prompt 中：

```bat
where python
python -c "import cv2, numpy, serial, requests, pytest, roarm_sdk; print('OpenCV:',cv2.__version__); print('NumPy:',numpy.__version__); print('Python dependencies OK')"
python -m pip show roarm-sdk
```

这里**只做 import**，不要执行 `roarm(roarm_type='roarm_m2',port='COMx')`。根据已核实的官方 `roarm_sdk/roarm.py` 实现，实例化 `roarm` 时会立即尝试打开串口；机械臂没到货，任何测试脚本默认 Mock，不得尝试发送运动指令。

## 4. 摄像头自检：现在即可做

用户已经确认 Windows 「相机」应用能出图，因此 USB 摄像头无需预装新驱动；但 OpenCV 能否打开、FPS 与实际格式需要进一步测量。

1. 先**关闭 Windows 相机应用**（它可能占用设备句柄）。
2. 在已激活 `visiongrasp` 的 Anaconda Prompt 中执行以下只读检测（默认摄像头索引 0，可按实况改成 1/2）：

```bat
python -c "import cv2; c=cv2.VideoCapture(0,cv2.CAP_DSHOW); ok,f=c.read(); print('opened:',c.isOpened(),'frame:',ok,'size:',None if f is None else f.shape,'reported_fps:',c.get(cv2.CAP_PROP_FPS)); c.release()"
```

若 `CAP_DSHOW` 不能打开，Codex #8 应尝试 `cv2.CAP_MSMF` 和其他 index，并报告实际结果；**不要把相机板上 `HD720P` 丝印当作 1280×720 30fps 的实测结论**。运行期间不要上传包含人脸/隐私信息的图像。

## 5. Clone 项目与 VS Code 选择 Conda Python

```bat
git clone https://github.com/Citlali6/VisionGrasp-Z19.git
cd VisionGrasp-Z19
git remote -v
code .
```

若旧仓库已克隆，不要覆盖原目录；按 [仓库更名迁移](../relaunch_20261020/REPOSITORY_RENAME.md) 更新 Git remote，打开已有项目即可。若 `code` 不是命令，可从 VS Code 的「文件→打开文件夹」选择仓库目录，无须因此重装。

VS Code 安装 Microsoft 的 Python、Pylance 扩展，使用 `Ctrl+Shift+P` → **Python: Select Interpreter** → 选择 `visiongrasp (Python 3.10)` 的 Conda 解释器。VS Code 内置终端不认 `conda` 时，优先从 Anaconda Prompt 中运行 `code .`，不必随意改 Windows 全局 Path。

## 6. Codex #14 后续交付要求（不能仅依赖手工安装）

- 以 **Conda 优先**替代旧文档中只写 venv 的要求，创建 `pc/environment.yml`（或有理据的等价锁方案），写出 `conda env create -f pc/environment.yml`（第一次）与 `conda env update -f pc/environment.yml --prune`（需审计时）的使用说明，避免误删或覆盖用户已有环境。
- 环境只要支持 Windows + Python3.10 + CPU。依赖清单需固定 NumPy/OpenCV/SDK 等**实际验证版本**，并说明 `roarm-sdk==0.1.1` 与官方 SHA 的对应/差异。可以使用 `pc/pyproject.toml` 打包项目源码；`environment.yml` 与 `pyproject.toml` 职责应区分，不用再要求创建额外 venv。
- 离线单测不得打开串口或调用运动；若 Codex 无法在真实 Windows + Anaconda 执行，报告 `NOT VERIFIED ON OWNER'S WINDOWS`，并给出负责人可复制的运行命令/输出收集步骤。
- 只操作 `Citlali6/VisionGrasp-Z19` 新分支，遵守 `AGENTS.md`，不改旧 `host/app/`、Z19 bit、ESP32 固件、不自动合并。
- 后续硬件兼容项：RoArm USB 连接需要先在设备管理器确认实际 COM 口/USB-UART 芯片，才决定是否需要安装芯片厂商驱动；不提前装一堆未知驱动。运动前必须 Citlali6 现场单独批准。

## 7. 常见错误

| 报错/现象 | 优先检查 |
|---|---|
| `conda is not recognized` | 是否在 Anaconda Prompt 运行；不要先给系统 PATH 乱加路径 |
| `ModuleNotFoundError: cv2` | `conda activate visiongrasp`、`where python`、`python -m pip show opencv-python` |
| `ModuleNotFoundError: roarm_sdk` | 检查 `python -m pip show roarm-sdk`；#14 核对包名和版本 |
| OpenCV 无画面 | Windows 相机占用、摄像头 index/backend、USB 数据线、摄像头隐私权限 |
| VS Code 可以运行但 Anaconda Prompt 不行 | VS Code 解释器与终端是否同一个 `visiongrasp` 环境 |
| `pip` 依赖冲突 | 不在 base 修补；提交安装日志让 #14 选择兼容版本，不擅自更新整套依赖 |

**总结：用户现有 Anaconda + Git + VS Code（若已装）即可开始准备；新增的是 Conda `visiongrasp` 环境中的 Python 包，而不是重新装一个操作系统或 ROS2 开发平台。**
