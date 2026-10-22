# Z19 USB 摄像头 PL 颜色识别 · 已验证交付包

[下载 ZIP](pl_color_z19_20261022_r3.zip) · [ZIP SHA256](pl_color_z19_20261022_r3.zip.sha256) ·
[源码与构建](../../fpga/color_locator/README.md) · [上板步骤](../../fpga/color_locator/BOARD.md) ·
[结构化验证摘要](validation/summary.json)

目标仓库：`Citlali6/VisionGrasp-Z19`，工作分支 `feature/pl-color-grid-20261022`。
这是用户现场验证过的**独立颜色识别诊断镜像**，适用 ALINX Z19 / XCZU19EG
及本轮核查过的 Linux/PS 初始化基线。不是完整机械臂抓取系统。

## 包含内容

将ZIP解压到一个新的外部目录（不要覆盖已有工程），得到：

- `firmware/`：已加载验证的bit、FPGA Manager原始bin和XSA。
- `native/color_camera`：实际运行过的AArch64程序，保留可执行权限信息；不是Windows程序。
- `source/`：颜色模块源码、测试、脚本、文档及其依赖的原PS配置；保留上游许可和出处。
- `reports/`：原始Vivado时序/DRC/资源报告。
- `validation/`：实际性能采样JSON、已有仿真PASS记录和验证摘要。
- `manifest.json`：包内逐文件SHA256、基线与适用环境。

ZIP外也保留可浏览的 `validation/`，无需下载二进制即可查看性能记录和报告。
源码是本分支审阅后的快照；Vivado重建得到的bit/BIN哈希可能不同，需要重新核验。

### 已验证文件

| 文件 | SHA256 |
|---|---|
|`firmware/visiongrasp-color-20261022-901f2f1fc6a8.bin`|`901f2f1fc6a812c25ed92e64f05bc5f15fc87c0ea417b9c3d26ce18454ebeb29`|
|`native/color_camera`|`8ae9478f6a0ef3f07d3b225a1a98584492ff352f331faf6f7955f3830f1590f2`|

原生程序动态依赖板端 `libjpeg.so.62`、glibc、libpthread及
`/lib/ld-linux-aarch64.so.1`；这些系统库不打包。源码可在同一Z19上用
`gcc -O2 -std=c11 -Wall -Wextra -Werror color_camera.c -ljpeg -pthread -o color_camera`
重新编译。

## 运行与恢复

1. 按上板说明检查相同Linux/PS时钟、独占PL使用者及未绑定旧PL驱动。
2. 把BIN上传到同名 `/lib/firmware/` 路径，核对完整SHA256；用源码中的
   `host/load_color.sh` 加载，再运行 `color_camera --selftest`。
3. 把C源码/原生程序、`preview.py`和加载脚本放在自己的板端版本目录，创建独立RAM预览目录。
4. 用 `preview.py --camera /绝对路径/color_camera --profile smooth` 管理相机，
   指定 `--directory` 与 `--port 18774`；不要同时另开第二个相机进程。
5. 用自己的SSH认证建立电脑8774到板子127.0.0.1:18774的本地转发，电脑打开
   `http://127.0.0.1:8774/`。详见上板说明。

加载脚本不会自动执行。manager的operating状态不能证明正确IP已加载；
须在加载审核过的本镜像后再进行native32寄存器自检。重启后需重新确认配置。
独立镜像会替换当前PL配置，不包含旧MIPI相机或MJC1控制逻辑，也没有物理执行器输出。

## 已验证效果和限制

- 720p真实USB采集、PL红绿蓝分割/高亮、像素计数和全局框、电脑显示通过。
- 原生基准4915200像素逐项通过；RTL的HSV数值、背压、AXI接口三组仿真通过。
- 640×480平均5.76fps，采集到板端发布平均221.43ms；720p平均1.93fps、561.76ms。
- 网络/显示延迟另计；不是30fps，提速仍需DMA。未实现同色独立目标、网格/标定或机械臂抓取。
- Vivado2020.1完整实现WNS4.580ns、WHS0.017ns；DRC0错误/25警告，详见报告。

不包含账号密码、license文件、SD镜像、私人相机图像、Vivado缓存或旧失效固件。
