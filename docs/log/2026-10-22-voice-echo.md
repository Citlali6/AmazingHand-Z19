# 2026-10-22：Z19 USB 中文识别与喇叭复述

## 授权与范围

用户明确要求：参考 VisionGrasp-Z19 现有工程，将麦克风/喇叭接 Z19 验证识别与播放，
验证正确后将代码放入此仓库。随后用户明确确认识别正确、复述清楚，再要求暂停识别。
本任务是独立音频验证，不执行 #12 全系统语音/机械臂集成，不更改团队主线优先级。

从干净 main `7b1163ed8ad734f5bf0ba31aaf4ac18291935273` 执行 ff-only 同步，
建立 `feature/z19-usb-voice-echo-20261022`；origin 为 `Citlali6/VisionGrasp-Z19`。
旧 Tom 仓库和其他原有脏工作区未修改。

## 实际板端发现与修正

- 网线最初显示 Disconnected；用户接好后为 100Mbps，已有 host key 校验的 SSH 登录成功。
  凭据仅在内存使用，未写入仓库、文件、参数或日志。
- Z19 是 PetaLinux2020.2 / AArch64 / glibc2.30 / Python3.7.6。USB PnP Audio
  `0c76:1203` 的录音/播放均可枚举，ALSA ID `Device`；最初缺 arecord/aplay/Vosk/TTS。
- 复用旧 Vosk 部署包，创建新的 `/opt/visiongrasp-voice-echo-20261022`，不覆盖系统 Python。
  安装先遇到旧包缺 importlib_metadata，补三个 Python3.7 兼容 wheel 和新 hash lock 后成功。
- 准备匹配 glibc 的 Debian 官方 ARM64 工具/库，只做隔离解压；无系统 apt/dpkg、无刷机。
  最初打包器拒绝 systemd 服务的 `/dev/null` 链接后停止；修正为不收录服务/系统配置再重建，
  没有绕过路径检查。最终 41 包，native payload SHA256 记录在 manifest。
- 基础 eSpeak 音质最终未通过用户听感确认；没有把 ALSA 播放成功当作音质成功。
  改用 Piper1.2.0 ARM64 和固定 Huayan 中文模型，板上 ldd 和版本检查通过。
  一条固定句合成约 4.3 秒，音频约 4.3 秒；仅单样本，不是延迟统计。
  用户对新固定句明确回答“这次中文清楚”。
- 实时 Vosk 识别 → 暂停/关闭采音 → Piper 合成 → USB 播放 → 冷却并重开采集，
  用户最终明确回答“识别内容正确，复述清楚”。电脑显示页只读取结果，未参与识别/合成。
- 用户要求暂停后，只对核实属于本次脚本的 PID1549 发 SIGTERM；随后进程和采音子进程退出，
  `/proc/asound/Device/pcm0c/sub0/status` 和 pcm0p 均为 closed，日志有 operator_stop。
  没有设置自动重启/开机启动，后续检查不能擅自恢复录音或播放。

## 源码与验证

新增独立 echo 模块、通用/隔离启动及安装脚本、依赖补丁锁、可复现资产/本地包工具、
PC 只读显示、校验记录及文档。沿用 `audio.py` 的 ALSA 采音，不修改旧控制/FPGA/PC 主线。

- `python -m unittest discover -s host/tests -p test_voice_echo.py -v`：13 项通过，exit0。
  首次一项测试误把 aplay 的 `-D` 当作后面的设备参数，修正测试索引后全部通过；未修改生产逻辑掩盖失败。
- 覆盖唯一/显式声卡选择、错设备/多设备拒绝、诊断不打开设备、UTF8 stdin、不执行 shell、
  合成失败禁止播放、Piper 私有库隔离、采音退出清理、JSON 中文输出。
- 本地包生成并核对现有基础 ZIP、native payload、TTS/模型及三个新增 wheel 的 SHA256。
  本地包及模型权重不提交：Huayan MODEL_CARD 的数据集许可为 Unknown，保留来源，不擅自重授权。
- 生成 179,603,884 B 本地 ZIP，SHA256 为
  `bb1b015029b26f554f51c7e50b12b828daf21dac51a2acb9fc69cd4c34ada426`。
  在新的 `/opt/visiongrasp-voice-echo-verified-20261022` 中完整解包，实际运行新安装脚本成功，
  `pip check` exit0，`--check` 枚举正确且 Vosk/TTS 模型存在；安装过程没有打开录音或播放。
  这个新部署没有重新执行真人识别验收；交互验收发生在先前明确记录的部署目录。
- 本轮没有运行主线 PC/RoArm/FPGA 测试或重装其依赖，没有伪称识别率或并发验收。

详细运行方法见 `docs/voice/Z19_USB_ECHO.md`。原始语音文本日志留在现场，不上传。
