# Windows Conda 实测记录（2026-10-21 / #14）

主线基线 `ed4965c`；工作分支 `feature/pc-sdk-issue14`。使用本机已有 Anaconda，在用户 Conda 环境目录新建 visiongrasp，未改 base/d2l/qpsk-radio/yolo。环境文件记录本次实际解析的版本，不表示未来上游最新版本。

| 项目 | 实测 |
|---|---|
| Python | 3.10.22 / Windows x64 |
| pip | 26.2.1 |
| NumPy | 1.26.4 |
| opencv-python | 4.10.0.84（cv2.__version__ 为 4.10.0） |
| SDK | 0.1.1，direct_url.json commit_id = d9893632aa7f5a9cb283136ab024faf3143ea7db |
| pytest | 9.1.1 |

实际操作和退出码：

1. `conda create --name visiongrasp python=3.10 pip -y`：0。
2. 首次将 SDK 与依赖一起默认 pip 安装：1，SDK 隔离构建缺 serial。失败日志保留，没有切换 SDK 版本。
3. 先安装 NumPy/OpenCV/pyserial/requests/simplejson/pytest/wheel/setuptools，再 `pip install --no-build-isolation` 安装固定 SHA：两步均 0。
4. `python -m pip install --no-deps --no-build-isolation -e pc`：0。
5. `python -m visiongrasp`：0，SDK/NumPy/OpenCV 成功导入，检查 feedback_get、joints_angle_get、pose_ctrl、gripper_angle_ctrl 签名；未实例化 SDK。
6. `python -m pip check`：0，No broken requirements found。
7. `python -m pytest -c pc/pyproject.toml pc/tests -q`：0，**19 passed**。

依赖安装日志、签名输出及含解释器位置的本机环境清单位于 `output/pc/issue14/`，不提交这些本机临时文件。可复现版本见工程 environment.yml；上游 SDK 安装必须遵守 README 的第二步。

测试覆盖接口合法/非法输入、NaN/Inf、单位、缺标定、状态枚举、未知机器人坐标及无设备 SDK 导入。测试夹具禁止 serial.open 和 cv2.VideoCapture，未打开任何串口或真实相机。

**WINDOWS DEPENDENCIES TESTED；CONTRACT TESTED；NOT VERIFIED ON REAL CAMERA；ROARM NOT TESTED；FPGA NOT TOUCHED。**
