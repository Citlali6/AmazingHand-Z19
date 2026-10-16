# Z19 Linux SD 启动与视觉部署前置核对

日期：2026-10-10。目标：Linux 启动、网络访问、IMX214 相机采集接入，再部署视觉推理。
本文保留材料核对与实施过程；最新板端结果见文末：正式 Linux 已启动并登录，
网线直连和 SSH 已通过，相机 0 已完成 Linux 十分钟采集；模型仍待部署。
相机配套方式与证据见 [Linux 相机验收](linux_camera0_bringup.md)。

## 已有材料

本机 `F:/嵌入式fpga比赛/sd/` 有以下文件，保留原件：

| 文件 | 字节数 | SHA256 |
|---|---:|---|
| BOOT.BIN | 30069712 | a1719b4dba5ea3520b9498e2063d557f4657e65cf8bf3ecfee72379445553b86 |
| boot.scr | 2007 | b3767ea01003c31baf90e3b1b541c7e385a5ab5db9952a9d07abbdec1b0d3eac |
| image.ub | 8726780 | e923606f9e5a428e7e76eb2b40a81415f474d041e980960220bcd2052fd978ad |
| rootfs.tar.gz | 278553681 | 4f05d24af1b04d3490dde9d3526c4119b9d2e08752b2954c96cfe167f57ddf34 |

核对结果：

- `image.ub` 是 FIT：ARM64 gzip 内核和设备树，无 ramdisk。内核和设备树的数据 SHA256 与各自 FIT hash 节点一致。此检查证明数据与内置校验值一致，不证明硬件兼容或来源身份。
- 内核为 `5.4.0-xilinx-v2020.2`，根文件系统 `/etc/issue` 为 PetaLinux 2020.2，hostname 为 `zu19eg_mipi`。
- 设备树启动参数为 `earlycon console=ttyPS0,115200 clk_ignore_unused root=/dev/mmcblk1p2 rw rootwait`。
- 根文件系统解压内容约 858 MB，有 Python 3.7、Python 2.7、gcc/g++、make、cmake、opkg 和 OpenCV 3.4 系列文件；未在 `usr/bin` 发现 pip/apt。实际运行能力待上板确认。
- `4cam_final/board/driver/mipi_cam.ko` 的 vermagic 为 `5.4.0-xilinx-v2020.2 SMP mod_unload aarch64`，与镜像内核版本字符串一致。仍需核对模块配置、符号版本、DMA 预留与实际加载结果。

## 硬件一致性尚未完成

使用本机 Bootgen 2020.1 的只读 `-read BOOT.BIN` 成功读取分区表：
FSBL（包含 PMU 固件数据）、PL bitstream、BL31、system.dtb、U-Boot。

PL 分区长度字段为 `0x006d3979` 个 32 位字，即 28632548 字节。
上次相机 XSA 内 `design_1_wrapper.bit` 为 12378816 字节。
容器与 bit 文件格式不同，不能仅凭长度确定逻辑功能，但当前没有证明启动包加载的是上次验证的相机设计。
读取两者同步字后的 IDCODE 写入值均为 `0x04a56093`，相机 bit 头标注 `xczu19eg-ffvc1760-2-i`；
器件标识一致，仍不能据此确定设计、时钟、复位或地址映射一致。
不得凭同名 `design_1_wrapper.bit` 认定一致，也不得在未核对 PS/PL 时钟、复位和设备树时直接替换其分区。

先保留整套启动材料；后续应对照实际相机 XSA、PL 配置和两个设备树完成一致性核对。

## SD 卡准备

接入读卡器时发现旧系统，之后用户明确授权清理。当前已确认 USB 序列号
`121220160204`、容量 `31268536320` 字节的目标卡已清理到空 MBR、零分区，
随后建立 FAT32 + ext4；当前根分区已完成安装。
旧卡启动材料没有用于本次安装；历史检查和清理证据见 [当天日志](../log/2026-10-10.md)。
磁盘号仅是临时枚举值，所有写入都按 USB 类型、序列号和容量重新定位。

本次采用 Windows 打包、Z19 RAM 恢复环境安装 ext4 的路线，电脑不装虚拟机或 WSL 系统：

| 分区 | 文件系统 | 内容 |
|---|---|---|
| 第 1 分区 | 1 GiB FAT32，偏移 1 MiB | BOOT.BIN、boot.scr、恢复/正常 FIT、rootfs.tar.gz、部署身份与校验清单 |
| 第 2 分区 | ext4 | rootfs.tar.gz 解压后的根目录树，含 bin、etc、lib、usr 等 |

第二分区使用剩余空间，MBR 类型 0x83；Windows 只建立分区，Z19 负责格式化 ext4 和解压。
不能只把 `rootfs.tar.gz` 复制到 FAT32 分区，也不能把压缩包解压到 NTFS/FAT32 后当作 Linux 根分区。
原始压缩包直接交给板端 GNU tar，保留数字 UID/GID、权限、符号链接、硬链接及设备节点。

### 已实现的准备工具

- `tools/build_z19_sd.py`：原件 SHA256 必须与上表一致；直接读取 tar，不在 NTFS 展开根目录。
  从原包选取静态 BusyBox、GNU tar/gzip、ext4 工具及 AArch64 ELF 动态依赖，生成 newc/gzip。
  保留原文件元数据；添加 `/init`、显式安装脚本和 console/null 设备节点。
- `tools/z19_image_formats.py`：标准 FDT v17、newc 和 legacy U-Boot script 编码。
  复用原内核，重算修改后的 DT 和 ramdisk SHA256；不伪造来源签名。
- `tools/prepare_z19_sd.ps1`：只接受已清理的指定 SD；拒绝已有分区，不执行 Clear-Disk。
  支持 `-WhatIf`；实际写入要求管理员 PowerShell。创建两分区，复制后逐文件校验。
- `host/scripts/z19_recovery_init.sh`：只读挂载 FAT 并进入串口 shell，**不自动安装**。
- `host/scripts/install_z19_root.sh`：显式 `--install ROOT_PARTUUID`；核对同盘 PARTUUID、
  SD 类型、容量、分区起止、挂载/交换使用状态和原包 SHA256；拒绝 eMMC、已有文件系统或已安装标志。
  完成解压、权限/read-back 和只读 fsck 后才写 `installed.env`，启用正常启动。

启动专用 DT 禁用 `/amba_pl@0`、`/pl_allocator@1`、`/xib_kmm@2` 和三个学长专用 buffer 预留。
原始 BOOT.BIN **未改动，FSBL 仍会加载其自带 PL**；禁用 Linux 节点不等于移除了 PL。
正常 FIT 当前也保持这些 PL 节点禁用，阶段 B 配套相机硬件和设备树验证通过后才能启用相机。

内核展开约 18.3 MB，加载地址为 `0x80000`；FIT 在 `0x10000000`，恢复 FIT 小于 64 MiB。
恢复 cpio 展开约 5.5 MB、gzip 约 2.7 MB，避免把完整约 858 MB 根目录塞入 RAM。
原 DT 低 DDR 为 0～`0x60000000`。这些边界已在 PC 检查，实际 DDR、U-Boot 重定位、
initramfs 加载和启动兼容性仍必须用串口实测确认。

### 准备与安装命令

在仓库工作分支、Windows 普通 PowerShell 构建；输出目录必须尚不存在：

```powershell
python tools/build_z19_sd.py --source 'F:\嵌入式fpga比赛\sd' --output 'F:\Amazing_Hand\tmp\z19-sd-package-20261010-v3'
& './tools/prepare_z19_sd.ps1' -Package 'F:\Amazing_Hand\tmp\z19-sd-package-20261010-v3' -WhatIf
```

管理员 PowerShell 实际写卡（本命令不会清除已有分区，部分执行后必须先检查现场）：

```powershell
& 'F:\Amazing_Hand\tools\prepare_z19_sd.ps1' -Package 'F:\Amazing_Hand\tmp\z19-sd-package-20261010-v3' -Confirm:$false
```

安全弹出后，断电将卡放入 Z19，确认 SD 启动拨码，连接 PS UART 并开始记录完整日志。
进入恢复 shell 后，用屏幕打印的 `ah_root_partuuid` **实际值**运行：

```sh
sh /install-z19-root.sh --install ROOT_PARTUUID
```

本卡写卡后 MBR 签名为 `47fcfe04`，root PARTUUID 已记录为 `47fcfe04-02`；
仍须以卡上的 `deployment.env` 为准，不能抄其他卡的值。
看到 `ROOT_INSTALL_COMPLETE` 后再 `sync`、`reboot -f`。
正常根分区内预建 `/opt/amazinghand/bin`、`models`、`calibration` 和持久日志目录
`/var/lib/amazinghand/log`，后续通过网络更新。原镜像 `/var/log` 是指向 volatile
目录的绝对链接，不从恢复环境沿该链接创建项目目录。

恢复入口：U-Boot 中设 `setenv ah_recovery 1`，然后 `run distro_bootcmd`（不执行 saveenv）。
恢复启动不会重装，已有 ext4 或 `installed.env` 会阻止格式化。若第一次安装中途断电留下 ext4，
工具也会拒绝重复擦除，须先只读检查并记录故障；不能自动清卡重试。

若系统文件已经完整解压，但安装在项目目录或验证阶段退出，可使用修订后的脚本：

```sh
sh /tmp/install-z19-root-resume-v2-20261010.sh --finish ROOT_PARTUUID
```

此路径是本次通过串口传入并校验 SHA256 的 RAM 文件，不是旧恢复镜像自带的文件。
以后重建包时，新 `/install-z19-root.sh` 自带 `--finish`。该模式重新核对 SD 身份、
PARTUUID、完整分区几何和原始 rootfs hash；只接受已有 ext4、无完成标志和未挂载根分区。
先只读 fsck，再以 `ro,noload` 挂载并用 GNU tar 逐项比较原始压缩包。
比较不一致或项目元数据已存在时拒绝继续；不格式化、不重新覆盖解压。
只有验证通过才创建项目目录、复制部署记录和诊断脚本，复查后启用正常启动。
chroot 内单独设置包含 `/usr/bin` 的 PATH，以执行镜像已有的 `getconf`。

AMD 的 [PetaLinux 2020.2 文件复制说明](https://docs.amd.com/r/2020.2-English/ug1144-petalinux-tools-reference-guide/Copying-Image-Files)
说明外置根文件系统应在 SD 根分区解压 `rootfs.tar.gz`。
本地 ALINX Linux 基础教程第 32 页的三文件 FAT32 示例需结合镜像根文件系统类型使用；不能直接套用到本包。
本次恢复包格式依据 [Linux newc buffer 规范](https://docs.kernel.org/driver-api/early-userspace/buffer-format.html)
和 [U-Boot FIT 说明](https://docs.u-boot.org/en/latest/usage/fit/howto.html)。格式检查不替代实际启动验证。

## 启动和系统验收

完成写卡与硬件一致性核对后，使用 Z19 板级资料确认 SD 启动拨码。
`docs/refer/Z19_key_specs.md` 记录 SW1 位序 4、3、2、1 为 ON、OFF、ON、OFF；
最终按实际 Z19 丝印和用户手册复核，不照搬其他开发板的开关朝向照片。
连接 PS_UART，串口 115200、8N1；PS 网口接可提供 DHCP 的网络。

首次启动需要保存 U-Boot 和 Linux 串口日志，核实：

1. U-Boot 识别 SD 卡并从 FAT 分区加载 image.ub。
2. 第一次进入 RAM 恢复 shell；显式安装完成后，以 PARTUUID 挂载 ext4 进入正式系统，不固定 MMC 枚举号。
3. 获得网络地址，确认镜像是否有 SSH 服务；不要假定 root 密码或 SSH 已启用。
4. 在板端运行仓库的只读诊断脚本：`sh host/scripts/probe_z19_linux.sh`。若仓库尚未部署，先复制脚本后运行。
5. 记录实际内核、glibc、Python、相机设备及 FPGA manager 状态，再决定软件部署方式。

## 相机和模型接入边界

已有 IMX214 Linux 实现位于本机 `4cam_final/board/`：
`mipi_cam.ko` 分配 DMA 缓冲并暴露 `/dev/mipi_cam`，用户程序通过 `/dev/mem` 映射寄存器及帧缓冲。
其 `MIPI_show/src/mipi.cpp` 展示 DMA 帧读取逻辑。板端部署前需要检查地址、帧布局、缓存一致性和驱动 ABI。
仅首路相机已有裸核图像证据，不能把四路示例当作四路已验证。

当前 `host/app/vision/camera.py` 的 OpenCVCamera 面向 UVC，不能假定 `/dev/mipi_cam` 可直接用 VideoCapture 打开。
下一阶段需选择已有 MJPEG 输出接入或专用 MIPI 帧源，明确图像颜色顺序、时间戳与陈旧帧判定。

当前根文件系统 Python 3.7 与仓库 `requirements.txt` 的 Python 3.10+ 环境不匹配。
首次启动阶段不执行整份 pip 安装，也不安装 PC 的 MuJoCo、PyTorch 和模型导出工具。
系统可用后，根据实际 glibc、存储和编译条件选择兼容的 Python 运行时/依赖，或评估已有 C++/OpenCV 路径接入 NCNN。
后续以实际相机帧的单图推理、结果叠加和持续运行作为验收；当前没有完成板端模型部署。

## 本次验证

`python -m unittest discover -s tools -p test_z19_sd.py -v` 覆盖二进制 CRC/hash、
64 位 FDT reservation、CPIO UID/权限/硬链接/设备节点、路径保护、ELF 架构和拒绝在 PC 安装。
Windows 自带 bsdtar 可独立读取实际 newc/gzip，确认文件及设备节点布局；板端 shell 脚本通过 `bash -n`。
写卡工具 `-WhatIf` 通过实际目标身份和整包校验；`test_prepare_z19_sd.ps1` 的 12 项模拟磁盘保护用例通过，
包含系统盘、错误序列号/容量、重复身份、GPT、只读/离线和非空卡拒绝；未调用磁盘写入命令。

**2026-10-10 18:35 实际写卡完成**：管理员 PowerShell 执行成功，日志
`F:/Amazing_Hand/tmp/z19-sd-prepare-20261010.txt` 记录 `SD_PAYLOAD_READY: E:\`。
8 个 payload 文件共 `331407720` 字节，复制后逐一 read-back SHA256 通过。
只读复查第一分区为 FAT32/type 0x0c、偏移 `1048576`、大小 `1073741824`；
第二分区为 Linux/type 0x83、偏移 `1074790400`、大小 `30193745920`。
当时第二分区尚未格式化；此为写卡阶段的历史状态。

**2026-10-10 19:24～19:27 正式系统已启动并登录**：根分区安装完成，软件重启后
从 `image-normal.ub` 加载，root 参数为 `PARTUUID=47fcfe04-02`，实际挂载为 ext4。
只读 fsck、原始 archive compare 和 glibc 检查通过，新的 root 初始密码已设置；
凭据仅保存在本机受限文件，不进入日志或 Git。

板端实测 Python 3.7.6、OpenCV 3.4.3、NumPy 1.17.0、GCC/G++ 9.2.0、Make 4.2.1，
约 26 GiB 根分区可用；没有 pip、NCNN 或 PyYAML，未建立 Python 3.11 环境。
没有 `/dev/mipi_cam` 或 `/dev/video*`；当前 FPGA manager operating 不代表相机就绪。

实际 PS 网口为 eth1（sysfs 对应 `ff0e0000.ethernet`）。保留原配置文件为
`/etc/network/interfaces.amazinghand-before-20261010`，删除原 `auto eth0` 行，
在原 `iface eth1 inet dhcp` 前加入 `auto eth1`；未改地址、驱动或设备树。
Dropbear 已监听 TCP 22。用户目前无法接网线，网络地址与 SSH 连接仍未验收。

用户要求仅做一轮断电启动检查；软件重启不算冷启动，三轮验收未完成。
每轮先正常关机，出现 `Power down` 后再由用户断电十秒并重新通电，独立保存串口日志。
**本轮已通过**：用户确认断电十秒后重新通电；U-Boot 为 SD_MODE1 / reset EXTERNAL，
FIT hash 通过，ext4 root 正常挂载，新凭据可登录，项目文件持久保存，eth1 已自动 UP，
SSH 仍监听 TCP 22。证据为 `tmp/z19-sd-coldboot1-20261010-193000.txt`；未接网线，
NO-CARRIER / 无地址不能计作网络连接通过。
当前 Linux 系统已在板运行，相机、模型及手控制仍未完成板端验收。

## 无路由器的电脑直连（19:42～19:46 已验证）

用户使用约 30 米网线将 PC Realtek 网口与 Z19 PS 网口直连，实测两端协商为
100 Mbps/full。电脑以太网已有手工地址 `192.28.14.152/24`，保留该配置和 Wi-Fi
默认路由；板卡 eth1 设置为 `192.28.14.153/24`，没有添加默认网关或 DNS。
此网段沿用本机现有设置，不是给其他电脑照抄的通用地址方案。

板端先保留 `/etc/network/interfaces.amazinghand-before-direct-20261010`，再将
eth1 的 DHCP stanza 改为 static，保持 `auto eth1`，使用 ifdown/ifup 生效。
四次 ping 全部通过，约 1～2 ms。已通过 UART 获取并核验 SSH 主机公钥，再建立
独立 known_hosts。该镜像没有接受本次 Ed25519 用户公钥，改用本机独立 RSA 3072
公钥后 SSH 登录成功；旧文件保留。私钥仅当前 Windows 用户可读，均放在忽略的 tmp。
兼容旧 Dropbear 的 ssh-rsa 选项只用于本次独立连接配置，不修改全局 SSH 设置。

在当前电脑连接：

```powershell
ssh -F F:/Amazing_Hand/tmp/z19-ssh-rsa-config-20261010 z19-direct
```

此文件引用本机私钥和已核验的主机公钥；不可把本机私钥复制给其他队员。
新 SSH 会话的非交互命令必要时显式设置 `PATH=/usr/sbin:/usr/bin:/sbin:/bin`。
传文件使用镜像支持的 legacy SCP：

```powershell
scp -O -F F:/Amazing_Hand/tmp/z19-ssh-rsa-config-20261010 LOCAL_FILE z19-direct:/DESTINATION
```

8 MiB 独立测试文件上传约 1.205 秒，板端 SHA256 与本机一致，下载回本机后再次一致；
该时间包含连接开销，不是长期带宽验收。结果记录为
`tmp/z19-direct-link-validation-20261010.json`。测试文件保留在本机 tmp 和板端
`/var/lib/amazinghand/log/z19-ssh-link-check-20261010.bin`，未覆盖已有文件。
这证明电脑与板卡的局域网通信和文件传输可用；板卡外网共享尚未配置。
