# Z19 Linux 相机 0 验收记录

日期：2026-10-10。已在正式 SD Linux 上取得相机 0 的真实 1920×1080 图像，
完成十分钟采集和停止检查；最终预览已升级为真实 1920×1080 MJPEG，电脑端实测约 25 fps。
用户确认相机部分按此现状收尾；没有部署检测模型。启动步骤见 [相机快速操作](camera_quickstart.md)。

## 本次配套方式

继续 `feature/camera-sd-bringup-20261010`，保留本次所有既有改动和原暂存区。
SD BOOT.BIN/FIT、FSBL、PMU 和原始相机 FPGA 工程均未修改。
正式 Linux 的 DT 已禁用旧 PL 驱动；本次在 Linux 运行后通过 FPGA manager
加载已验证相机 XSA 的同一份 bit，使用独立的相机 0 bench 驱动。
参考 [AMD 2020.2 对应 FPGA manager 用法](https://xilinx-wiki.atlassian.net/wiki/pages/viewpage.action?navigatingVersions=true&pageId=1661009925)。

固定材料和检查：

- XSA SHA256：`1f85a8611799568ee331fd9d5c86634e6af3ec3c22eb20624be0a98cba6d658c`。
- XSA 内 bit 与此前实际裸核拍图使用的 bit **逐字节相同**；SHA256 `28e1e3e7963ff12f57848998cf2695dcca139c3f519c5f020daf90dec4dc35ae`。
- 本机现有 Bootgen 2020.1 转换 raw bin：SHA256 `e25e9bc7fd4c2008c7a198a91bc4937716b333259d08da7ed777d8ffe9b3384b`；SCP 后板端再次匹配。
- PS I2C0/1、EMIO 相机连接；PL0/1 实测约 200703980 / 100351990 Hz、启用计数为 1。频率沿用正常系统现有 RPLL，未在运行中重写 PS 时钟。
- 只读核对 PS HP1：`0xFD615000 & 0x300 = 0x200`，`0xFD390000/14 & 3 = 0`，相关 AFI reset 位为零，满足此 XSA 的 128-bit 接口。未在运行中改变 AFI 宽度。
- VDMA `0xA0060000`，版本读值 `0x62000050`；GPIO `0xA0080000`，Gamma `0xA0040000`。不访问旧设计对应的 VDMA 地址。
- XSA 派生参数写六帧，原配置参数写三帧；实测 bit 索引为 0/1/2。驱动有三块缓冲，六组地址寄存器全部指向已分配内存的别名，消费者只使用实测三帧。

## 编译、分配和首次出图

板端 GCC/G++ 9.2.0、Make 4.2.1，Linux `5.4.0-xilinx-v2020.2`。
将内核 header/build 树复制到独立 `/var/lib/amazinghand/build/kernel-camera-20261010`，
构建 `scripts`、`asm-generic`、`prepare0`，补齐缺失的 ARM wrapper 和 modpost。
原 `/lib/modules/.../build` 保留；没有安装 PC ARM 依赖、VM、WSL 或新 FPGA 工具。
syncconfig 仅增加编译能力标记 `CONFIG_CC_CAN_LINK` 并更新编译器名字，运行内核未变。

原驱动源码缺 `slab.h`、`of_device.h`，直接重编译失败；未修改原材料。
新源码位于 `host/camera_linux`，固定宽度 ioctl ABI、排他打开、只读 DMA API 映射。
模块实际加载成功，使用 DMA32 从 CMA 分配 18665472 字节：
`0x50100000 / 0x506EF000 / 0x50CDE000`，stride 6221824，单帧有效 6220800 字节。
没有通过 `/dev/mem` 映射 DMA 内存；仅 GPIO/Gamma 的固定寄存器仍由 bench 程序访问。

相机 ID=`0x0214`、分辨率回读=1920×1080、stream=1、传感器计数 27→33。
最初 500 ms 等待仍为空；检查原 CSI RTL 发现 200M byte-clock 的 FIFO reset、
随后 100M byte-clock 的写入门控。改为最多 30 秒等待真实帧，首次成功等待 3.360 秒。
该改动是 Linux 软件等待逻辑，未修改或重新综合 FPGA 源码。

十秒采集记录 555 次缓冲区轮转并保存真实现场图像，RGB/BGR 两种解释文件均保留。
图像偏雾，仍需结合实物调整焦距、确认镜头状态与标定；不能据此宣称光学质量验收通过。
提供的 Bayer RTL 输出 R/B/G，Gamma 保持组件顺序，XSA subset remap 变为
R/G/B 高位到低位；据此推断 little-endian DMA 字节为 B/G/R。预览按 BGR→RGB
生成 PPM，raw 保留原始字节；最终光学颜色仍需已知色块实测确认。

## 十分钟采集

使用焦距位置 300；这是手动镜头位置，不是自动对焦。

| 项目 | 实测 |
|---|---|
| 采集时长 | 600 秒（启动等待后开始计时） |
| 缓冲区轮转观察次数 | 33333 |
| 轮转观察率 | 55.555 次/秒；不是带硬件时间戳的无丢帧 FPS 测量 |
| 每秒检查记录 | 599 条 |
| 不同图像采样 hash | 599 个 |
| DMA 错误样本（mask 0xff0） | 0 |
| 空图像样本 | 0；最小非零抽样点数 1240 |
| 写入索引覆盖 | 0/1/2（mask 7） |
| 结束 | `DMA_HALTED`，`CAPTURE_COMPLETE`，完整 raw 6220800 字节 |

本机证据目录 `F:/Amazing_Hand/tmp/z19-linux-camera-20261010`：
`camera0-linux-fourth-20261010.{txt,raw}`、首帧 PNG、
`camera0-linux-10min-20261010.{txt,raw}`、`camera0-linux-10min-validation.json`。
板端原始记录位于 `/var/lib/amazinghand/log`，没有覆盖前三轮失败诊断记录。

## 缓冲区清理和浏览器

- ABI/未知 ioctl 拒绝、可写/部分/偏移/private mmap 拒绝通过。
- 第二个打开被拒绝；fd 关闭但 VMA 尚存时，排他状态和模块引用仍保留，卸载被拒绝；VMA 关闭后可重新打开。
- 正常停止顺序：传感器 stream off → VDMA halted → 保存已完成 store → unmap → close。
- SIGKILL 采集进程后，最后文件释放路径停下 DMA；重新打开回读 halted，映射/模块引用检查通过。
- 停机失败时驱动保留 DMA 分配并拒绝新打开，不释放给其他用途；此故障路径未以硬件卡死实际注入。
- 浏览器 12 个 JPEG 均不同；最新帧时间和序号来自 monotonic metadata。预览帧为 320×180、最多 5 次/秒，采集仍是 1080p。640×360 直接读取 uncached DMA 的成本过高，未作为实时预览发布。
- SIGSTOP 采集后返回 STALE，JPEG 返回 503；SIGCONT 恢复 LIVE。
- SIGKILL 后返回 ERROR/503；重启恢复 LIVE；主动停止返回 STOPPED/503。
- 非法焦距 1024 返回 400，不写镜头。焦距应用为手动 I2C 设置。
- 实际焦距 300/0 的 API 均成功；现场低分辨率抽样锐度没有显著改善，恢复 300。不是自动对焦，也不据此确定最佳光学位置。
- 预览包保存于 `/opt/amazinghand/camera0-linux-20261010`；`start_preview.py` 以独立进程启动，SSH 退出后继续运行。重复启动被拒绝；强制结束 server 后，采集检测到父进程消失并停止，DMA halted 实测通过。

HTTP 预览由板端现有 Python 3.7/OpenCV 提供，不运行识别或手控制。
Windows 系统代理可能将直接连接的 `192.28.14.153` 请求送入代理；验收客户端使用
只针对本次请求的直连设置，没有修改 Windows 或 Git 全局代理。

## 连续视频与电脑本地入口（后续修订）

用户反馈浏览器无法打开、需要流畅视频。Windows 代理已启用，但 bypass 规则不含
`192.28.14.153`，默认客户端经代理请求失败；只针对此应用的直连 HTTP 请求成功。
新增 PC 端 `view_camera.py`，只监听 `127.0.0.1:8766`，直接转发固定板端相机路由，
不更改系统代理、网卡、路由或 SSH 配置。本地入口 `http://127.0.0.1:8766/`。

板端 `/stream.mjpg` 使用持续 multipart MJPEG，替代每 200 ms 重载 JPEG 的页面。
采集每 1/30 秒尝试发布最新 320×180 画面，保留原 25 ms/写入索引的复制保护；
未修改驱动、DMA 缓存属性、FPGA 或传感器表。页面状态检查与视频传输分开，
显示实测发布帧率；客户端只接收最新帧，采集停顿后旧连接结束、新请求返回 503。

从电脑本地入口连续接收 20.023 秒：590 帧，590 个不同 JPEG，29.416 fps，
发布率 29.410 fps，预览序号零缺失；帧间隔 p95=34.148 ms、最大 37.452 ms，
JPEG 有效载荷约 1.315 Mbps。这是本次 PC 接收测试，未宣称无丢帧 1080p 视频
或浏览器实际渲染帧率。预览仍为 320×180，光学清晰度问题仍待处理。

MJPEG stale EOF、SIGSTOP/SIGCONT、SIGKILL→DMA halt、重新启动、主动停止、
非法焦距拒绝均实际通过，最终恢复 LIVE。证据：
`tmp/z19-linux-camera-20261010/smooth-stream-validation-20261010.json`、
`camera0-smooth-fault-validation-20261010.json`。
新版 userland 独立部署到 `/opt/amazinghand/camera0-linux-smooth-20261010`，
原包保留；新版 capture ELF SHA256 为
`ad938c22cdf2706f209a8c0fe62dcdd0c6af2bb7693a140af8d012d6714e66df`。
浏览器自动验证工具无法连接，自动打开浏览器命令被自动审批拒绝；
未将 HTTP 接收测试写为浏览器显示验收。

## 1080p 视频定版与收尾

用户希望预览达到高清后，改为复制整个 DMA store，不从 320×180 放大。
单线程完整读取约 41.9 ms；四片并行 idle 实测约 14.0 ms，运行编码时通常约 20～26 ms。
新增 `camera_preview.c/.h`：四片复制到普通 RAM，两个 libjpeg-turbo worker 异步编码；
采用板端已有 libjpeg-turbo 2.0.3、BGR 输入、quality 85/fast DCT。
Python 直接传送已编码 JPEG，移除 OpenCV 解码/重新编码；未安装新包。
JPEG worker 不接触 DMA/MMIO/I2C，旧帧或忙碌时丢弃并计数，metadata 保证单调。

从帧索引刚变化时开始复制；完整前后状态查询/复制窗口限制为 30 ms，
并拒绝选中 store 已变为写入中的结果。限值仅适用于此固定约 55.6 Hz profile：
完整覆盖并绕过选中 store 至少需两个周期约 36 ms；不得用于更快模式。
驱动、mmap 缓存属性、传感器配置、PS/PL 和 SD 启动文件未修改。

最终 PC 本地入口测试 30.047 秒接收 757 个不同 JPEG，每一张解码为 1920×1080；
25.161 fps，发布序号零缺失，capture monotonic 严格递增；
帧间隔 p95=70.443 ms、最大 85.625 ms，JPEG 有效载荷约 21.076 Mbps。
这是当前实景/客户端条件下的接收测量，不保证固定 30 fps 或无丢失传感器帧。
另一次完整 60 秒高清采集发布 1666 张，copy/busy/obsolete discard 均为零；
观察 3333 次 store 轮转，正常 `DMA_HALTED`、worker join、保存 6220800 字节 raw。
原十分钟采集与此前低分辨率试验均保留，不将 60 秒高清试验写为十分钟高清串流。

新版故障注入再次通过：已有 MJPEG stale 时关闭、新请求 503、SIGCONT 恢复、
SIGKILL 后 DMA halt、重启、主动停止和非法焦距拒绝；最终恢复 LIVE。
本机证据在 `tmp/z19-linux-camera-20261010`：
`hd-stream-guard30-validation-20261010.json`、`camera0-hd-fault-validation-20261010.json`、
`camera0-hd-60sec-20261010.{txt,raw}`。
最终包 `/opt/amazinghand/camera0-linux-hd-20261010`，保留此前两版包；
capture ELF SHA256 `fdb6ed7b6c3fd7961a2e089fff9cd392baae74453d01085a0f292c95874b4ce2`，
配套驱动 SHA256 `56bc43d3153ed861a598293ea7d38920806107c1ec8eaac4b70eeb87f62fe368`。

用户已确认当前预览可用并要求收尾。光学雾感/焦距、实物色块核验、标定、
自动加载/冷启动、第二路和模型推理留为后续工作，本轮不继续扩展相机功能。

## 待完成

当前为手动加载的 Linux 相机 profile；重启仍加载原 SD 基线 PL。
相机配置自动加载和相机冷启动可靠性尚未验收，第二路仍未推进。
光学清晰度、相机内参/尺度、模型推理和抓取闭环均独立待验收。
源码与命令见 [`host/camera_linux/README.md`](../../host/camera_linux/README.md)。
