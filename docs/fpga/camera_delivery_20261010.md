# Z19 相机阶段交付（2026-10-10）

已完成单路 FL0214/IMX214 的 Linux 1920×1080 采集和电脑实时观看。
实测 30.047 秒接收 757 张不同的全尺寸 JPEG，约 **25.16 fps**；用户已确认可用并同意相机阶段收尾。
该成果没有包含目标识别、语音或真实手控制。

## 工程与功能说明

| 路径 | 功能及关键注释所在位置 |
|---|---|
| `fpga/camera_hw/` | 原相机 XPR/BD/XDC、所需 CSI/Bayer/Gamma IP、已验证 bit/XSA；README 和 manifest 说明来源/版本/hash |
| `fpga/camera_baremetal/` | 历史 JTAG 源码、链接脚本、对应 ELF、独立旧 ELF/符号；README 按函数说明用途及复现边界 |
| `host/camera_linux/ah_camera0.c` / `ah_camera0_uapi.h` | DMA32 三帧、排他设备、只读 mmap、START/STOP/STATUS ABI 和 fd/VMA 生命周期；源码注释说明 halt 失败处理 |
| `host/camera_linux/capture_camera0.c` / `sensor_table.h` | 传感器初始化、真实帧预热、手动焦距、采样与正常退出；结束先停 DMA 再释放映射 |
| `host/camera_linux/camera_preview.c` / `.h` | 四段复制完整帧、两个 JPEG worker、30 ms 复制保护、RAM 编码/递增发布和丢弃计数；注释说明固定 profile 限制 |
| `host/camera_linux/preview_server.py` / `start_preview.py` | 高清 MJPEG、启停/焦距 API、过期画面关闭和拒绝、脱离 SSH 启动 |
| `host/camera_linux/view_camera.py` | PC 本地 HTTP 入口直连板端固定路由，避免系统代理影响；不改系统网络设置 |
| `host/camera_linux/test_device.py` / `test_preview.py` / `test_stream.py` | 设备生命周期、故障恢复、逐张 JPEG 解码/序号/接收帧率验收 |
| `host/camera_linux/validated/` | 最终板端 ELF/模块的字节归档及适用内核说明 |
| `host/scripts/` | Linux 诊断、受保护 rootfs 安装/收尾、恢复环境、相机 profile 加载 |
| `tools/build_z19_sd.py` / `z19_image_formats.py` | 原文件 hash 核对、FDT/FIT/CPIO/boot.scr 生成，不在 PC 执行板端程序 |
| `tools/prepare_z19_sd.ps1` / `clear_z19_sd.ps1` | 显式 SD 身份/几何/参数检查及授权执行；保护系统盘，不自动选择另一张卡 |
| `tools/capture_z19_uart.ps1` | 串口记录，辅助定位首次启动/安装问题 |
| `docs/fpga/evidence/2026-10-10/` | 高清流、故障测试、十分钟采集和部署 hash 的原始 JSON 指标 |

以上是已有功能说明，不修改经过验证的 PL 参数、传感器值或手控制协议。
供方工程保持原字节/版权；仅归档实际依赖的配置与源码，没有收录 build cache/DCP。

## 其他成员复现

1. 从本交付分支获取工程，先读 [硬件说明](../../fpga/camera_hw/README.md)。已验证 bit/XSA 可用；
   可编辑源工程需要 Vivado 2020.2。现有本机只有 2020.1，本次没有重新综合/实现，不承诺源工程重建 bit 字节相同。
2. 准备同一 Z19 SD Linux 基线和自己的账号/SSH 认证；原 `BOOT.BIN/image.ub/rootfs.tar.gz` 不在 Git。
   [SD 部署记录](linux_sd_bringup.md) 与脚本保留其预期 hash。磁盘写入脚本绑定已核实的本机 SD 身份，
   其他卡必须先人工核实身份/几何并按授权调整，不可直接绕过拒绝检查。
3. 参考 [Linux 编译说明](../../host/camera_linux/README.md)，复制相机源文件、配套二进制及 loader 到板端。
   可使用 `validated/` 中当前内核对应的 ELF/模块，或在隔离的内核 build tree 编译；不要在 PC 安装板端包。
4. 按硬件 README 将 bit 转换为已知 hash 的 raw firmware，确认 PS 时钟/HP1 和无占用后执行 loader。
   板端运行 `python3 start_preview.py`，PC 运行 `python host/camera_linux/view_camera.py`。
5. 打开 `http://127.0.0.1:8766/`，操作详见 [快速操作](camera_quickstart.md)。
   当前固定直连地址为 PC `192.28.14.152` / Z19 `192.28.14.153`；SSH 私钥与密码只保存在各自本机。

## 验证与剩余边界

SD 正常系统登录、一轮断电启动、直连 SSH/SCP/hash 已通过；不是三轮冷启动验收。
Linux 600 秒采集 DMA 错误/空样本为零，故障测试和最终高清流逐帧解码通过，详见
[验收记录](linux_camera0_bringup.md) 和 [JSON 证据说明](evidence/2026-10-10/README.md)。
交付前 PC 的 9 项 SD Python 测试、12 项 PowerShell 拒绝检查、standalone 重新编译、脚本语法和归档 hash 核对通过。
Linux C 曾在板端以 `-Wall -Wextra -Werror` 编译并实机运行；此次归档二进制 hash 与最终部署一致。

约 25 fps 是当前场景的电脑接收结果，页面可显示实际发布速率；不保证固定 30 fps 或无传感器丢帧。
焦距是手动位置；光学雾感/颜色/标定、第二路、相机开机自动加载及冷启动、识别模型和手控制为后续任务。
重启后仍需手动加载相机 profile。系统镜像、现场照片/raw/视频、缓存及登录凭据保留本机。
