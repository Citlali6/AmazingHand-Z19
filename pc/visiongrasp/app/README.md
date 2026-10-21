# PC 可视化演示（Issue #18）

先按 [PC 安装步骤](../../README.md)准备 visiongrasp 环境。以下命令从仓库根目录执行；主程序只提供 mock 机器人模式，不接受串口或 real 机器人参数。

## 无设备运行

```bat
conda activate visiongrasp
python pc/scripts/demo.py --mode mock --camera synthetic --synthetic-calibrated --frames 0
```

合成红蓝色块 + 明确标识的合成桌面标定（300×200 mm 是测试数据，不是实测桌面）。点击色块选择，再点击 CONFIRM & RUN MOCK；底部显示七阶段。模拟机器人真实 XYZ 始终 None，不声称运动学或抓稳实物。

离线自动验收命令：

```bat
python pc/scripts/demo.py --mode mock --camera synthetic --synthetic-calibrated --headless --auto-run --frames 300 --snapshot output/pc/demo/dashboard.png
python -m pytest pc/tests
```

`--auto-run` 是调用者显式批准的合成测试确认，仅 synthetic 允许。退出码 0 表示模拟七阶段完成，2 表示拒绝、故障或未完成；没有相机和串口副作用。

## 实验室真实相机 + FakeRobot（负责人现场验证）

当前尚未验收 SIM1319-HD720P；不要将内置摄像头当作这块 USB 板。关闭 Windows 相机程序，先用 #8 的 camera_probe 确定正确索引和实际尺寸，再显式传入该 index：

```bat
python pc/scripts/demo.py --mode mock --camera live --camera-index 1 --backend dshow --frames 0
```

1 是索引示例，须替换为实测值；无法打开时检查 DSHOW/MSMF、USB 连接和 Windows 隐私权限。实时帧来源显示 LIVE_PC_UVC，机器人仍显示 MOCK，未标定时显示 UNCALIBRATED，不允许启动模拟抓放。

桌面标定：固定相机，测量同一平面矩形的宽和高；启动参数加入 `--table-width-mm` 与 `--table-height-mm` 的**实际测量值**，点击 CALIBRATE 后依序点击左上、右上、右下、左下四角。成功后以独立版本写入 output/pc/demo/table-<UUID>.json，重新选择色块再确认执行。标定期间不能启动动作。后续可用 `--calibration` 加载保存文件，图像尺寸/来源变化时失效。桌面单应性不是机械臂基座标定，也不生成真实抓取 Z。

需要调色时先用 #8 camera_probe 的 `--tune` 检查 HSV/面积参数；主程序可用 `--detector-config 文件.json` 加载 DetectorConfig 字段。参数说明见 [视觉模块](../vision/README.md)。不要把规则检测分数解释为神经网络置信度。

## 操作与日志

- 点击框内选择目标；ENTER 或确认按钮开始本次 Fake 动作。重复点击不会重复排队。
- S、空格或 STOP 按钮阻止后续阶段；相机断流、目标消失/明显移动、旧帧或标定变化也会取消。STOP 不代表物理急停。
- Q/Escape 或关闭窗口退出，停止任务并释放相机。采集与动作在后台执行，界面不等待动作完成。
- JSONL 位于 output/pc/demo/logs：含 UTC/单调时刻、来源、帧/会话、桌面标定、目标、阶段、错误、FAKE/None 坐标。默认不保存视频或现场图像。
- `--snapshot` 是显式保存一张界面 PNG 的选项；真实相机截图由负责人检查隐私后再决定是否分享，程序不会上传。

## 到货后人工验收清单

本程序不提供真实机械臂开关。后续 #10/#11 另行核对机械臂型号/固件、供电与固定底座、可断开的独立电源、串口唯一占用、反馈单位与夹爪方向、限速及实测工作域、桌面到基座坐标及抓取高度，再由负责人批准受控 R0/R1/R2。没有这些证据，不将 MOCK 完成改称真实抓放成功。
