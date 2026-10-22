# Z19 微雪 USB 麦克风识别与喇叭复述

## 已验证的内容（2026-10-22）

本轮用户明确要求独立验证板端语音，验证正确后上传代码。基线 main 为
`7b1163e`，工作分支 `feature/z19-usb-voice-echo-20261022`。

```text
USB TO AUDIO 板载麦克风
  → Z19 PS / ALSA / 16kHz 单声道 PCM16
  → Vosk 中文识别
  → Piper 中文语音合成
  → ALSA / 同一个 USB TO AUDIO / 外接喇叭
```

识别、合成和播放都在 Z19 的 A53 CPU 上进行，没有使用 PC 识别、云接口或 FPGA PL。
电脑上的可选网页只读取板端识别结果，不能发送机械臂或板卡控制指令。

- 板卡：ALINX Z19，PetaLinux 2020.2，AArch64，glibc 2.30，Python 3.7.6。
- 设备：USB `0c76:1203`；本轮 ALSA ID 为 `Device`，录音和播放均为
  `plughw:CARD=Device,DEV=0`。其他板卡须先枚举，不能照抄序号。
- 物理设备支持双声道 PCM16，ALSA plughw 转换成识别器要求的 16kHz 单声道。
- Vosk 0.3.45，`vosk-model-small-cn-0.22`，复用仓库旧离线包。
- Piper ARM64 1.2.0 / `2023.11.14-2`，中文 `zh_CN-huayan-medium`。
- 用户现场最终明确确认：**“识别内容正确，复述清楚”**。随后要求暂停，板端录音及
  播放接口均读取为 `closed`；本轮未配置开机启动或自动恢复。
- 这是短句交互验证，不代表已统计识别率、远场性能、延迟分布或与相机/PL 并发通过。
- 新打包/安装脚本已在另一全新板端目录完成离线安装及 `pip check` / 无设备打开的
  `--check`，均 exit0；没有为此重新开启已暂停的麦克风。

### 保留的失败与修正

1. 旧离线包在真实 Python 3.7 安装时缺少 tqdm 的间接依赖，pip 解析失败。
   新增独立的 `host/requirements-voice-echo.lock`，补齐并校验
   `importlib_metadata==6.7.0`、`typing_extensions==4.7.1`、`zipp==3.15.0`。
   原历史包及其 manifest 保持原样。
2. 基础 eSpeak 合成虽然返回成功，用户后续反馈“有很多个音，但不知道说的什么”。
   不能将首次接口返回成功当作音质验收。切换到实板 Piper 后，用户再次确认中文清楚。
   默认使用 Piper，不静默回退到基础合成器。
3. USB 混音器检查：扬声器 84% / -10dB，麦克风录音 82% / 25.5dB，
   麦克风直通播放关闭。本轮只读检查，未修改这些设置。

## 源码入口

| 路径 | 用途 |
|---|---|
| `host/app/voice/echo.py` | 板端独立枚举、固定句播报、实时识别及复述 |
| `host/app/voice/audio.py` | 复用既有 ALSA 采音，不修改旧命令词/控制模块 |
| `host/scripts/voice_echo.sh` | 已有环境中的通用入口 |
| `host/scripts/voice_echo_install.sh` | 本地离线验证包的独立安装 |
| `host/scripts/voice_echo_standalone.sh` | 独立安装后的固定版本启动入口 |
| `tools/voice_echo_monitor.py` | 可选 PC 只读文字显示，绑定 127.0.0.1 |
| `tools/prepare_voice_echo_runtime.py` | 准备匹配旧 glibc 的 ARM64 ALSA 工具与运行库 |
| `tools/prepare_voice_echo_piper.py` | 下载固定 hash 的 Piper 和中文本地测试资料 |
| `tools/package_voice_echo.py` | 从现有离线包和上述资料生成本地验证 ZIP |
| `host/tests/test_voice_echo.py` | 13 项无设备测试 |

播报前关闭本程序拥有的录音子进程，播报后等待 700ms，再新建采集进程，避免将
播放期间缓存的自身语音送回识别器。它是半双工复述验证，不是声学回声消除或全双工对话。
任何设备错误都报错退出，不自动重连，不切换到电脑内置麦克风。

## 依赖来源与校验

固定文件、来源、大小、SHA256 见：

- [板端录放音运行库](echo_native_assets_20261022.json)
- [Piper 和中文模型来源](echo_tts_assets_20261022.json)

运行库来自 Debian 官方 Buster ARM64 存档，适用于本轮 glibc2.30 板端，
仅解压到独立目录；不执行 apt/dpkg，不覆盖系统库、不刷镜像。
工具会校验固定 Packages 索引 hash 和每个包的 SHA256；这些是哈希核对，
未声称执行了独立的 Release 签名验证。第三方 copyright/许可证随包保留。

**中文模型 MODEL_CARD 将数据集许可证写为 Unknown。模型权重及完整本地测试包
没有上传 Git，也不被项目 Apache 许可证覆盖；本轮只在本机/板端测试使用。
公开分发模型或产品化之前须另行核清授权。** 仓库上传的是自写适配代码、校验值和复现工具。

## 准备独立离线验证包（PC）

以下示例输出目录均须全新，不覆盖既有目录。若需代理，仅为当前终端设置，
不更改全局 Git/系统配置。PC 不安装或执行 ARM64 库。

```powershell
python tools/prepare_voice_echo_runtime.py D:/voice-assets-NEW/native
python tools/prepare_voice_echo_piper.py D:/voice-assets-NEW/piper
python -m pip download --dest D:/voice-assets-NEW/extra-wheels --platform manylinux2014_aarch64 --python-version 37 --implementation cp --abi cp37m --only-binary=:all: importlib_metadata==6.7.0 zipp==3.15.0 typing_extensions==4.7.1
python tools/package_voice_echo.py D:/voice-assets-NEW/local-board-voice.zip --native D:/voice-assets-NEW/native --piper D:/voice-assets-NEW/piper --extra-wheels D:/voice-assets-NEW/extra-wheels
```

生成的 ZIP 仅供本地验证，不要将其当成可公开分发的 Release。
它包含旧包中固定的 Vosk 模型/ARM64 wheels、新增的三个 wheel、源码、启动脚本、
独立运行库和本地 TTS 测试资料，不包含密码、SSH key、录音或当前聊天文本。

## 板端安装与手动验证

将生成包复制到板端一个**新的空目录**，在该目录执行：

```sh
python3 -m zipfile -e local-board-voice.zip .
sh host/scripts/voice_echo_install.sh
sh host/scripts/voice_echo_standalone.sh --check
sh host/scripts/voice_echo_standalone.sh --speak '你好，这是开发板语音测试。'
sh host/scripts/voice_echo_standalone.sh --listen --seconds 600
```

安装器拒绝覆盖已有 `.venv`、`native` 或 Piper 目录。它只创建包内 Python 环境和
运行库；运行前先确认这块板的架构、glibc 和系统 Python 与本轮一致。

`--check` 不录音、不播放。说完短句停顿一两秒，等待播报结束后再说下一句。
默认最多运行 600 秒，最多允许 3600 秒；Ctrl+C 停止并释放本程序的子进程和声卡。
同一声卡一次只启动一个验证进程，不要另开旧 listen/record 或其他采音程序。

如存在多个 USB 音频设备，必须从 `--check` 的枚举结果选择：

```sh
sh host/scripts/voice_echo_standalone.sh --listen --seconds 600 \
  --input-device plughw:CARD=Device,DEV=0 --output-device plughw:CARD=Device,DEV=0
```

已经独立安装工具和 Vosk 的 Linux 环境可使用通用入口，显式给出 Piper 和模型路径：

```sh
VOICE_PYTHON=/absolute/env/bin/python sh host/scripts/voice_echo.sh --listen \
  --tts-executable /absolute/piper/piper --tts-model /absolute/zh_CN-huayan-medium.onnx
```

## 可选 PC 显示

在 PC 独立诊断环境安装 `paramiko==3.5.1`，不要修改主线 Conda base 或锁定的 PC 依赖。
从可信既有连接取得板子 host key，放入专用 known_hosts 文件。工具严格校验 key，不自动信任新板。

```powershell
python tools/voice_echo_monitor.py --host BOARD_IP --user root --known-hosts C:/path/board_known_hosts --log /absolute/voice-session.jsonl
```

密码从终端提示读取，不写入参数、文件或日志。打开 `http://127.0.0.1:8773/`。
关闭显示程序不会自动停止板端语音；板端应在自己的终端 Ctrl+C 或向记录的、已核验属于
本程序的 PID 发送 SIGTERM，不能用广泛的 pkill 杀掉其他任务。

## 验证边界

- 本轮 13 项新增离线测试通过；它们不是硬件成功证据。硬件效果由用户现场确认。
- 不连接 RoArm、不消费或发布运动命令、不访问 `/dev/mem`、不加载 FPGA bit。
- 任意聊天文本只显示和复述，不进入旧 KWS 动作接口。
- 不保存麦克风 WAV；合成 WAV 在本次播放结束后删除。JSON 事件包含识别文字，
  如自行重定向保存日志，应作为本地语音文本处理，不随代码上传。
- 不修改 #12 的团队优先级或宣称主线视觉抓放已完成。
