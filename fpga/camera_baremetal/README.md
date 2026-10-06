# Z19 / FL0214 裸机摄像头联调

2026-10-06 已在 Z19（XCZU19EG）+ FMC1 FL0214 上取得第一路 IMX214 的
1920×1080 图像，并通过 JTAG 在电脑显示连续的 320×180 预览。
这是独立的摄像头联调程序，使用学长的四摄像头硬件平台，不是仓库舵机 PL 的集成工程。

## 已验证与边界

- 摄像头 ID 为 `0x0214`；第一路连续采集、VCM 对焦位置 300 的 I2C 写入成功。
- 修正后的现场检查：80 帧、80 个不同图像、无全零黑帧，观察约 57 秒，预览约 1.3 fps。
  证据见 [evidence/2026-10-06.json](evidence/2026-10-06.json)。哈希变化证明图像数据更新，
  不等于已经验证手势识别或用户挥手进入视野。
- 修复 Windows 替换被读取文件时的占用错误：每帧使用独立 RAW/JSON 文件名，先完成 RAW
  再写 JSON；读端重试尚未完整的 JSON，只保留最近 8 组输出，页面显示 LIVE/STALE/ERROR。
- 现场写帧索引只轮转 0、1、2，后三个缓冲区未写入；按模 3 取上一帧消除了周期黑帧。
  XSA 元数据声明 6 个帧存储，实际硬件与平台配置的一致性仍需单独审查，不能把此观察
  推广到其他 bitstream。
- 对焦是设置镜头位置，尚无自动搜索算法；预览缩小后放大显示会损失细节。
- 第二路曾能读到 ID，但未成功采图；双目同步、冷启动可靠性、色彩校准、Linux、
  与舵机工程共存、AI 推理均未验证。I2C 使用厂商轮询接口，不能视为生产级容错程序。

## 外部输入

本次输入为学长提供的 `4cam_final/mipi_only_4cam/design_1_wrapper.xsa`，
使用其中匹配的 `psu_init.tcl` 与 `design_1_wrapper.bit`；原工程由 2020.2 生成，
现场使用 Vitis/Vivado 2020.1。硬件平台不在这个源码目录重建，需保留原工程资料。

`src/sensor_table.h` 的有效寄存器序列提取自学长工程
`board/fl0214_config/src/imx214.cpp` 的 `sensor_init_data[]`；对焦格式取自其
`imx214_set_focus()`，I2C 地址为 `0x0C`。`camera.ld` 改自生成的 A53 FSBL 链接布局，
保留 Xilinx MIT 声明。没有修改摄像头原硬件设计或仓库 PS/PL 接口契约。

## 构建

以下在 Windows PowerShell 中运行。工具安装路径按自己的电脑调整。
输出目录必须是新的目录；2020.1 工具读 XSA 时建议使用英文工作路径。

```powershell
$cameraRoot = 'F:/Amazing_Hand/fpga/camera_baremetal'
$vitisRoot = 'F:/Xilinx/Vitis/2020.1'
& "$vitisRoot/bin/xsct.bat" "$cameraRoot/prepare.tcl" 'F:/camera-input/design_1_wrapper.xsa' "$cameraRoot/build/platform-20261006"
if ($LASTEXITCODE -ne 0) { throw 'BSP generation failed' }
$cameraBsp = "$cameraRoot/build/platform-20261006/platform/camera_hw/psu_cortexa53_0/standalone_domain/bsp/psu_cortexa53_0"
& "$cameraRoot/build.ps1" -BspDir $cameraBsp -VitisRoot $vitisRoot -OutputDir "$cameraRoot/build/capture-20261006"
```

已有匹配 BSP 时可直接运行 `build.ps1`。产出 `capture.elf`、`symbols.tcl`、`manifest.json`
和 map；预览地址自动从本次 ELF 提取，不要沿用其他构建的地址文件。
`requirements.txt` 仅用于电脑预览，依赖为现场 Pillow 版本，不安装到板端。

## JTAG 下载和预览

先确认 JTAG、PS UART 和板卡供电已接好，启动方式按 Z19 手册核对。
现场使用 COM7 / 115200 / 8N1。下面会重置处理器；可选初始化步骤还会重新配置 PL。
此程序不写 Flash 或 SD 卡，不控制灵巧手。

启动本机 hw_server（端口 3121）后，准备一个含匹配 `psu_init.tcl` 和
`design_1_wrapper.bit` 的输入目录，例如 `F:/camera-input/hardware`：

```powershell
$cameraBuild = "$cameraRoot/build/capture-20261006"
& "$vitisRoot/bin/xsct.bat" "$cameraRoot/run.tcl" $cameraBuild 'F:/camera-input/hardware'
if ($LASTEXITCODE -ne 0) { throw 'JTAG download failed' }
python "$cameraRoot/viewer.py" --build $cameraBuild --xsct "$vitisRoot/bin/xsct.bat"
```

PS/PL 已完成匹配初始化时可省略 `run.tcl` 的最后一个参数，仅重新下载应用。
冷启动流程仍须验证；这个脚本不代表冷启动已通过。
打开 `http://127.0.0.1:8765/`，刷新页面后查看画面、帧号、图像年龄和对焦结果。
只运行一个预览读端，不同时重新下载或重置。网页“停止采集”会请求关闭摄像头输出；
直接关闭网页不会停止后台预览。停止后再次运行需重新下载应用。

运行文件保存在本目录 `runtime/<时间戳>/`，构建与运行目录均由局部 `.gitignore` 排除。
原始 XSA、bitstream、SDK 生成平台、ELF、图像和实验室照片留在本机，未随本次提交上传。
