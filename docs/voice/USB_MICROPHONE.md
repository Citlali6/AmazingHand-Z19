# 微雪 USB TO AUDIO：语音基础工程

## 当前交付与边界

目标硬件：微雪 USB TO AUDIO（板载麦克风），接 Z19 **PS USB HOST**。
语音由 PS 上的 Vosk 中文小模型识别，PL 继续承担手控制。

源码提供：设备枚举、环境报告、录音、PCM转换、WAV/实时中文识别、JSON命令输出，及主程序的sim输入入口。
**麦克风尚未到货：没有真实USB录音、识别率、延迟或相机/PL并发验收结果。**
本工程不打开 `/dev/mem`、不加载bit、不改相机固件、启动文件、密码或防火墙。
语音CLI仅输出命令，**没有连接正在运行的MJC1闭环**。接入时由原控制进程消费命令，保持唯一MMIO写入者，不能同时启动旧 `backend_fpga`。

开发副本：`D:/Vitis/project_1/voice_usb_foundation_20261018`。
工作分支：`feature/usb-voice-foundation-20261018`。原目录及相机集成目录的未提交修改保留。

## 固定音频格式

- 识别器输入：16000 Hz、单声道、16位有符号小端PCM，100ms一块。
- Linux实时采音：`arecord` + ALSA `plughw`完成声道/采样率转换；无需PyAudio。
- 自动选择仅接受**恰好一个**USB录音设备；零个或多个时明确报错。可用 `--device` 指定。
- WAV入口支持PCM16、单/双声道、16/32/48kHz；可选mix/left/right声道。整数比降采样用简单平均，未做拾音/降噪效果标定。
- 24位、浮点、44.1kHz或压缩音频明确拒绝，不会当成16位数据送入识别器。

配置在 `host/config/voice_usb.json`。其中model路径相对该配置文件解析；不依赖启动目录。
`device: null` 为唯一USB自动选择；设备到货后以实际枚举结果为准，不预填声卡号。

## 板端环境与离线安装

独立语音CLI面向Python3.7+ / Linux AArch64；依赖 `vosk==0.3.45` 和系统 `alsa-utils`。
PC上准备的AArch64 wheel不能安装到Windows环境。不要安装根目录混合视觉/仿真的requirements。

先在板端查看实际环境：

```sh
python3 --version
uname -m
cat /etc/os-release
command -v arecord
ls /dev/snd
```

若缺arecord，需按**当前Linux镜像**安装匹配alsa-utils；若没有录音设备，先核对USB枚举及内核 `CONFIG_SND_USB_AUDIO`，不把“免驱”理解为所有镜像均已启用驱动。
当前ALINX系统曾报告Python3.7.6/AArch64；未在本次语音任务中重新读取板卡状态。

将准备好的部署目录复制到板端一个新的版本目录，例如 `/opt/amazinghand/voice-usb-20261018`。
在该目录执行（不依赖板端联网）：

```sh
python3 -m venv .venv
.venv/bin/python -m pip install --no-index --find-links wheels pip==24.0
.venv/bin/python -m pip install --no-index --find-links wheels --require-hashes -r requirements-voice.lock
export VOICE_PYTHON=/opt/amazinghand/voice-usb-20261018/.venv/bin/python
sh host/scripts/voice_usb.sh check
```

若板端没有venv/ensurepip，不要使用系统级强制安装或从PC复制Windows环境；保留报错，再为该镜像补齐对应组件。
离线包包含模型、按Python3.7/AArch64解析的依赖、固定版本hash锁文件；原生共享库仅静态核对ELF架构，未在PC执行板端库。包内pip24.0是Python3.7兼容的独立环境安装工具。
`check`只报告环境和模型文件是否存在，不表示模型已推理成功，也不启动录音。

## 麦克风到货后

### 1. 列出录音设备

```sh
sh host/scripts/voice_usb.sh devices
```

输出中会有类似 `plughw:CARD=Device,DEV=0`。这只是示例，以实际设备为准。
只有一个USB录音设备时，下列命令可以省略 `--device`。

### 2. 录10秒真人语音

```sh
sh host/scripts/voice_usb.sh record /tmp/usb_voice_001.wav --seconds 10
```

录制时说“抓起香蕉”“放下”“停下”“复位”。录音只保存在指定位置，已有文件会拒绝覆盖；失败时可能保留部分录音以便排查。
不需要另接喇叭就能录音和识别。建议利用随附USB延长线调整位置，实际对比风扇噪声下的拾音效果。

### 3. 从录音识别

```sh
sh host/scripts/voice_usb.sh wav /tmp/usb_voice_001.wav
```

### 4. 实时输出命令

```sh
sh host/scripts/voice_usb.sh listen --seconds 60
```

Ctrl+C关闭本工具自己的录音进程。拔出设备、音频停滞或识别失败会报错退出。
**本命令输出JSON，不直接让手运动。** 每次listen会话seq从1开始，跨进程接入应另加session/接收时间校验。

## 麦克风未到时可用的入口

在仓库 `host/` 目录：

```sh
python -m app.voice text "抓起香蕉"
python -m app.voice normalize existing_stereo_48k.wav voice_16k.wav
python -m app.voice wav voice_16k.wav --model /path/to/vosk-model-small-cn-0.22
```

text只解析文字，不是语音识别证据。WAV识别需要真实录音及模型；本次没有用合成输入冒充真人录音。

## 主程序的sim演示入口

完整原host主程序仍按仓库要求使用Python3.10+；本板现有Python3.7先使用上面的独立CLI。

```sh
python -m app.main --backend sim --voice-wav voice_16k.wav
python -m app.main --backend sim --mic --seconds 60
```

真实语音输入仅开放sim后端，避免接到尚未冻结的旧FPGA ABI。
这里的sim是已有软件后端，**不是当前桌面MuJoCo/真实PL闭环**。视觉仍为固定banana的MockVision，只能用于“抓起香蕉”基础演示；其他目标没有匹配视觉结果时会超时，不会拿banana计划代替。
WAV入口为单条命令；包含多句的文件使用语音CLI逐句输出，不用它做整段手动作回放。
麦克风模式按实际时间推进，新增语音路径每拍查看停止/释放；退出时请求停止并关闭采音。

## 命令输出契约 amazinghand.voice/1

```json
{"schema":"amazinghand.voice/1","source":"microphone","seq":1,"text":"抓起香蕉","accepted":true,"confidence":0.92,"reason":"accepted","command":{"action":"grasp","target":"banana"}}
```

上例为格式说明，非实测。action为grasp/release/stop/reset，target为既有物品表内部名称。
置信度为该句最低词置信度，默认阈值0.65，需真人录音后再定，不是准确率。
默认完整中文模型解码后过滤，SetGrammar仅保留为显式可选接口；没有未经验证就把整句中文当成模型词条加载。
空白、未知词、低置信度和非完整白名单语句不形成控制命令；如“不要抓香蕉”“打开音乐”“抓起香蕉放下”均拒绝。
MicVoiceSource限制队列长度、丢弃超过2秒的普通事件、抑制1秒内重复命令；停止优先且锁住后续运动，复位后仍需新运动命令。
USB断开错误优先报告，接入控制器时必须将采集错误转成停止；语音“停”不能代替实体急停。

## 到货后的验收顺序

1. Linux枚举到USB声卡；查看实际支持格式，确认16kHz/mono PCM转换可用。
2. 录音可听、无削波/长段静音；拔插后明确报错并能重新启动。
3. 真人分别说命令、否定句、聊天、连续命令；记录识别结果、错误和结束到命令的时间。
4. 明确说话距离/噪声/人数，再统计命令成功率及误触发率；当前没有这些数据。
5. 经接口联调将命令交给MJC1现有进程，核对停止锁存、显式复位、丢弃旧命令和反馈ACK。
6. 最后做相机、语音、PL/虚拟手并发验收。当前相机+MJC1集成固件另有时序问题，不能算本次语音已解决。

## 官方依据

- 产品：https://www.waveshare.net/wiki/USB_TO_AUDIO （USB/Linux/16kHz录音资料）
- Vosk：https://alphacephei.com/vosk/install （Linux arm64、PCM16k mono要求）
- ALSA：https://www.alsa-project.org/main/index.php/Asoundrc （plug转换机制）

本次没有新增或运行测试；源码静态检查、依赖与模型打包结果记入开发日志。真实录音和端到端验证待麦克风到货后执行。

## 重建离线资料与部署包（PC）

所有输出目录必须为新的空白路径，不覆盖旧交付物：

```powershell
python tools/prepare_voice_model.py D:/Vitis/project_1/voice-assets-NEW
```

在PC隔离的Python3.9打包环境准备依赖（仅构建纯Python srt wheel，其他板端依赖只下载不安装）：

```powershell
python -m pip wheel --no-deps --wheel-dir D:/Vitis/project_1/voice-assets-NEW/wheels srt==3.5.3
python -m pip download --platform manylinux2014_aarch64 --platform linux_aarch64 --python-version 37 --implementation cp --abi cp37m --only-binary=:all: --find-links D:/Vitis/project_1/voice-assets-NEW/wheels --dest D:/Vitis/project_1/voice-assets-NEW/wheels -r host/requirements-voice.txt pip==24.0 setuptools==67.8.0 wheel==0.42.0
python tools/package_voice_usb.py D:/Vitis/project_1/voice-package-NEW --model-assets D:/Vitis/project_1/voice-assets-NEW --wheels D:/Vitis/project_1/voice-assets-NEW/wheels
```

依赖解析会随上游更新；本次交付的实际版本、文件hash保留于包内manifest和lock。下载模型hash为本地记录，不声称厂商签名验证。
