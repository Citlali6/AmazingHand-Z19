# USB 摄像头的 PL 颜色识别：开源选择与接入边界

日期：2026-10-22；分支 `feature/pl-color-grid-20261022`，从同步后的 main
`7b1163ed8ad734f5bf0ba31aaf4ac18291935273` 新建。此文记录独立 PL 支线，
不修改 PC+RoArm 演示主线优先级，也不把软件视觉结果称为 FPGA 检测结果。

**本日后续上板状态：**用户随后明确要求上板验证。已经完成真实USB→PS格式传输→
PL识别→电脑显示，1280×720，约1fps。红色方块、绿色物品、蓝色包装在画面中分别
保留匹配颜色；真实PL自检通过。详细复跑和寄存器见
[上板说明](../../fpga/color_locator/BOARD.md)。下文保留开源选择和早期OOC证据，
不应再将早期“未上板”状态当作当前状态。

## 1. 现场与仓库核查

- 主板 ALINX Z19 / `xczu19eg-ffvc1760-2-i`；可用 Vivado、Vitis HLS2020.1。
- 用户原先把 USB 摄像头接电脑。已有 PC OpenCV 代码实际打开 index1/DSHOW，
  接收1280×720、约10.4fps；它的 HSV 规则在 PC 上运行。
- 用户明确告知已改接 Z19 USB Host。随后 SSH 只读核查确认 `0bda:9143`
  摄像头、`/dev/video0` 和 `/dev/video1`，名称均为 USB Camera；内核 UVC 已内建。
  后续V4L2确认video0为capture、video1为metadata；支持720p MJPEG和YUYV。
  此次实际采用MJPEG1280×720，请求10fps；不能把枚举的60fps当成显示帧率。
- 板上 PetaLinux2020.2 / kernel5.4 / AArch64 / Python3.7.6；`v4l2-ctl` 已存在。
  通用 `CONFIG_XILINX_DMA` 未启用，不能直接照搬 PYNQ Overlay/DMA Python 接口。
  这不代表芯片没有 DMA，也不代表所有现有 DMA 通路均不可用。
- `fpga/camera_hw` 归档处理的是四路 MIPI/RAW10/Bayer/Gamma/VDMA，配套
  Vivado2020.2；不是这只 USB UVC 摄像头的输入设计。其已有 bit 不含本次颜色模块。
- 先前电脑预览在 USB 摄像头被拔走后变为黑帧，已只关闭本任务启动且路径核实的
  PID47716，没有关闭其他应用、恢复持续录音或加载 FPGA 固件。

## 2. 真实开源项目比较

### A. 本次选用的底层 RTL

[laperex/image_processing_fpga](https://github.com/laperex/image_processing_fpga)
（提交 `0a33843ab7dee60cca22082db42e4f8eb4c180e1`）提供 SystemVerilog RGB→HSV
与 HSV 区间掩码，MIT 许可。原平台 PYNQ-Z2 / Zynq7020，原构建使用
Vivado2024.1、Python3.14 自定义工具。

核查发现，原 AXI 包装只透传 tready，自由运行的转换流水线未停顿；作者也列出
丢像素风险。其原工程不是可以直接下载到 Z19 的固件。本次仅复用
`cv_types.sv` 和 `cv_rgb_to_hsv.sv`，保留逐字节源码和 MIT 许可，新增本地
流量控制/阈值封装。源码链接与 SHA256 见 `fpga/color_locator/vendor/laperex/UPSTREAM.json`。

### B. 官方 HLS 备选

[Xilinx/Vitis_Libraries 的2020.1颜色检测例程](https://github.com/Xilinx/Vitis_Libraries/tree/2020.1/vision/L1/examples/colordetect)
已核实存在，固定提交 `99f6218d8e723a2c4b37228757978592643ca8c3`。
Apache-2.0；C++ HLS 的 BGR→HSV、颜色阈值、腐蚀和膨胀可生成硬件，
不是要求 PC 用 OpenCV 执行在线检测。

原例包含测试程序，配置默认128×128，尚需修改尺寸并重新做 HLS/RTL验证。
例程输出掩码，不会自动提供本项目的网格坐标。此轮做源码核查，未声称它在
本机通过 HLS 综合或上板。若后续需要硬件形态学滤波，这是可靠的参考方向。

### C. 神经网络教学备选

[Marco-Winzker/NN_RGB_FPGA](https://github.com/Marco-Winzker/NN_RGB_FPGA)
固定提交 `2af69f50daf02bdc378655466da2110829ebdb5d`，VHDL 小型颜色分类网络，
有720p视频接口、离线训练脚本及 `sim_nn_rgb.vhd`。根许可证 MIT；但其
`sigmoid_IP.vhd` 是 Intel `altsyncram` 生成件，附 Intel 工具/IP使用声明，
不能把它自动当作通用 MIT 的 Xilinx ROM。移植还需要替换 ROM、视频时钟/接口和训练参数。
没有核实到完整 USB 摄像头、目标框或网格定位链路；本轮未编译这个项目。

### D. 仅作算法参考

[karabowiczjakub/FPGA-verilog-projects/vision-pipeline](https://github.com/karabowiczjakub/FPGA-verilog-projects/tree/main/vision-pipeline)
有 YCbCr 分割、中值滤波、质心和视频显示 Verilog。
提交 `43e1c0ca382554a2e74456a21333d7b96c6e01b7` 未发现根 LICENSE，依赖输入
视频环境，也不是完整 Z19 工程，因此没有复制到本项目。

附件指定的两个 OV7670 工程也已查阅：[AngeloJacobo](https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface)
是 VGA/SDRAM 相机采集参考；[VichekaMET](https://github.com/VichekaMET/FPGA-with-Camera-Summer-internship-2026-)
描述运动差分目标框，不能当作已完成的 RGB 颜色目标定位。这些 OV7670 接口均不适用 USB UVC 引脚。

## 3. 此轮真实实现与验证

新增 `fpga/color_locator`，结构为 RGB888输入流 → 原开源定点HSV核心 →
选定颜色阈值 → 有容量预约的输出FIFO → RGB原像素+掩码输出流。
配置在首像素SOF锁存，避免帧内变色；复位清除未处理数据；首个SOF前不产生检测掩码。
所有算法在可综合 RTL 中；电脑仅离线生成测试参考，不参与部署算法。

Vivado2020.1 实际验证：

1. 1024组数值参考通过（H环形误差≤1、S误差≤2、V精确），同时检查有效信号和TLAST对齐。
2. 2064个输入输出像素逐个核对通过，包含红绿蓝/off、灰白黑黄、暗红、帧标志、
   输入间隙、3910次源暂停周期、4108次输出保持检查、帧内配置变化、在途像素复位丢弃。
3. `xczu19eg-ffvc1760-2-i` OOC综合通过：379 LUT、374 FF、0 BRAM、**4 DSP**。
   早期控制台中间统计显示3个DSP48原语，最终 utilization 的DSP总数为4，以后者为准。
4. 10ns时钟下综合网表 WNS6.014ns；存在 OOC 时钟源/偏斜上下文缺失提示。
   未布局布线、未验证集成时序、未生成或加载 bit，不能声称实际最大频率或720p30已验收。
5. 初次仿真启动脚本因 Windows 反斜杠被 Tcl 解释而未运行；改用正斜杠后，
   使用新输出目录重跑通过。没有改测试期望或删掉失败证据。

完整接口、复跑命令、默认阈值和数据格式见 [模块说明](../../fpga/color_locator/README.md)。
原始检查/仿真/资源报告留在本机独立 `D:/Vitis/project_1/pl_color_validation_20261022/`，
其中源文件出处、提交和 hash 可复核；不提交波形、DCP或摄像头私人画面。

## 4. 上板接入进展与后续验收门槛

1. **已完成。**用 V4L2 查询并短测板端USB格式，保持PS只负责采集/格式传输；不能将MJPEG/YUYV
   字节直接当作本模块的0x00RRGGBB像素。
2. **已完成PIO诊断，DMA待做。**设计并验证匹配当前 Linux 的 PS内存→PL→PS内存通路。
   必须在实际BD中分配地址、核对时钟复位；不探测旧相机/MJC1固定地址来猜新IP是否存在。
3. **已完成本诊断接入。**将本模块作为单时钟视频流级接入，验证1280像素行标志、720行SOF、输出背压和原图对齐。
   原模块没有行列长度计数/坏帧检测；应由适配器严格校验帧长并丢弃截断数据。
4. **已完成。**新建可审查硬件工程，综合/实现/DRC/时序和加载前检查后上板。
   用户明确授权此次验证；未修改启动文件。完整实现WNS4.580ns、WHS0.017ns，
   0时序失败、0 DRC错误（25条警告），1885LUT/1936FF/0BRAM/6DSP。
   原生32位真实PL红绿蓝自检及720p相机帧通过；图像在8774页面显示。
5. 增加每网格独立统计、面积过滤、包围框、同色多目标歧义状态；再通过同一完整帧的
   缓冲/重放在PL生成标注，禁止用上一帧框冒充当前帧目标，也不能在PC画框冒充PL叠加。
6. 最后接真实音频识别与命令码；当前 `cfg_color` 是颜色模块测试/配置口，
   不是语音识别。坐标输出阶段不驱动机械臂。

当前已打通真实USB→PL颜色通路，但只有低帧率诊断和全局颜色包围框。
缺口是后续DMA提速、独立目标/网格定位、同帧框叠加、命令接入与安全抓取；
不能把本次颜色高亮演示称作完整抓取系统。
