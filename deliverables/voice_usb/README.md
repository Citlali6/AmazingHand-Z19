# USB 麦克风离线部署包

适用设备：ALINX Z19 的 AArch64 Linux、Python 3.7，麦克风为微雪 **USB TO AUDIO**。

## 下载与内容

- [完整离线包 voice_usb_package_20261018_v2.zip](voice_usb_package_20261018_v2.zip)：约 48.5 MiB，在 GitHub 文件页点击下载原始文件。
- [SHA256 校验文件](voice_usb_package_20261018_v2.zip.sha256)。
- [完整安装和使用说明](../../docs/voice/USB_MICROPHONE.md)。

压缩包包括独立语音源码、配置、启动脚本、中文识别模型、15 个离线依赖 wheel、依赖 hash 锁文件、模型来源记录及逐文件 manifest。解压后进入 `voice_usb_package_20261018_v2/`，按安装说明操作；不必在板端下载模型或 Python 依赖。

仓库中的 `host/app/voice/`、`host/config/voice_usb.json`、`host/scripts/voice_usb.sh` 和 `tools/` 保存可维护源码。压缩包是 2026-10-18 的固定部署快照；后续修改源码时需要重新打包，包内 manifest 用于核对快照内容。模型和依赖的许可说明保留在模型目录及各 wheel 中。

## 当前完成程度

**2026-10-22 补充：**下面是 2026-10-18 冻结包的准备状态。麦克风现已到货，
板端 ARM 关键词识别与真实 PL 颜色定位已完成现场红色联动，另有绿色状态证据。
当前入口见[联动说明](../../fpga/color_locator/VOICE.md)与
[补充运行库和相机程序](../voice_pl_color/README.md)。旧包保持原样供复现模型和 wheel。

- 已准备 ALSA 采音、录音文件转换、Vosk 中文离线识别、命令白名单过滤和结构化命令输出。
- 已完成语法、配置、压缩包完整性及文件 hash 静态检查；原生依赖按 AArch64/Python 3.7 准备。
- 麦克风尚未到货：USB 音频驱动、`alsa-utils`、Python 独立环境、实际录音及识别效果仍待板端确认。离线包不包含板端内核或 ALSA 系统组件。
- 语音输出尚未接入当前运行的 MJC1 控制进程。仓库主程序中的语音示例仅开放软件仿真，不能据此认为已实现语音控制 FPGA/虚拟手。

本交付不更改相机、FPGA 固件或正在运行的虚拟手连接。
