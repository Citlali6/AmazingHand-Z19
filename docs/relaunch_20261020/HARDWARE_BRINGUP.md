# 硬件上手、接线、回退、验收指导

> 本文件含真实设备操作风险。任何上板加载 bit、掉电/上电、驱动安装、固件烧录、串口发送**运动**指令，只能在 **Citlali6 当次现场批准并由现场人员实施/陪同** 后进行。Codex 可离线准备程序，但不自动执行。所有命令先确认正在操作的是本仓库对应设备/真实版次。

## 0. 硬件、配件和布局

- 已知：Z19 XCZU19EG 与对应扩展板；RoArm-M2-S 标准整机已下单（含夹爪、ESP32、独立 12V5A 适配器、USB 通讯线和桌面夹具，具体物品开箱核实）；实验室 USB 摄像头在树莓派使用过，可借；PC Windows + Vivado/Vitis 2020.1；板端旧 PetaLinux 2020.2/Linux 5.4/Python 3.7/OpenCV 3.4，旧平台不得擅自重装。
- 尚需现场准备：稳固桌面、USB A 数据线（机械臂线与摄像头线不能共用一根）、颜色对比明显的轻质方块 2~3 个、实物标定纸和直尺、固定俯视摄像头支架、可迅速可触及的独立 12V 断电方式，必要时安全眼镜。
- 摄像头优先**独立固定在桌面上方**，不要装在移动机械臂末端：后者需要动态手眼标定，不适合十日 MVP。
- 禁止让 Z19 的 USB 给机械臂舵机供电；RoArm 使用独立电源并确认适配器匹配厂商标准。电源周围保持可断开并留出手指安全距离。

### 建议物理布局

\`\`\`text
固定相机（俯视，不随机械臂动）
            ↓
  [目标区 A/B]     [投放区]
            轻量彩色方块
    <---- 桌面工作区 ---->
          [机械臂基座，桌夹稳固]
               |
     USB-A/TypeC 串口----Z19 PS USB Host
     独立 12V5A 电源----RoArm
     USB UVC 摄像头------Z19 PS USB Host 或 PC（明确标注）
     Z19 PS AXI ↔ Z19 PL FSM（一个经过验收的 bit）
\`\`\`

不得先假设空间/高度可达，必须测安全工作域、机械臂碰撞路径、桌面余量。

## 1. D1 只读 Z19 设备检查（无改动）

现场使用板卡原有受信 SSH 登录，不在公开 Issue/日志保存密码、私钥、真实隐私图像。

\`\`\`sh
uname -a
uname -m
python3 --version
lsusb
ls /dev/video* /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true
lsmod | grep -E 'uvcvideo|cp210x|usbserial|videodev' || true
test -r /proc/config.gz && zcat /proc/config.gz | grep -E 'CONFIG_USB_VIDEO_CLASS|CONFIG_USB_SERIAL_CP210X' || true
test -r /lib/modules/$(uname -r)/build/.config && \
  grep -E 'CONFIG_USB_VIDEO_CLASS|CONFIG_USB_SERIAL_CP210X' /lib/modules/$(uname -r)/build/.config || true
dmesg | tail -50
\`\`\`

\`/dev/video0\` 没出现≠ 摄像头故障；也可能是内核没有 UVC、线材只充电或设备没枚举。先用 \`lsusb\` / dmesg 区分。设备节点出现也≠能采到正确图像。若 \`CONFIG_USB_VIDEO_CLASS\` 缺失，保留本机镜像，不强行换内核；走 PC 采集保底。

## 2. USB 摄像头采集验收

1. 室友确认型号、曾用的软件路径；建议先在 PC 上以 OpenCV \`VideoCapture\` 打开摄像头、保存一张带实际日期/场景的样例和输出尺寸/FPS。
2. 用户批准后在 Z19 USB 插入，记录 \`lsusb\` VID/PID、\`/dev/videoX\`、V4L2 支持的格式/帧率；\`v4l2-ctl\` 若未安装不是阻断，不要为此全局升级。
3. 优先 640×480 / MJPEG 或 YUYV，真实测试解码、颜色顺序、丢帧、读取耗时与连续运行；原项目的 \`/dev/ah_camera0\` IMX214 DMA 用户态接口**不能原样接 UVC**。
4. 如果摄像头由 PC 接入，PC 的控制权限仅为“传送视觉结果”；将相机 session、frame_seq、PC 收到时刻、目标坐标、标定号带入消息，Z19 以接收时刻+序号做活性检查，要求操作员确认，禁止直接从 PC 控制 RoArm。

## 3. RoArm 开箱和 PC 最小台架验收

**仅现场人员，先不上电：** 拍摄配件清单、检查机械臂/夹爪、12V5A 标识、电源线、USB线和底座，固定桌夹。关节远离人体、障碍和桌沿，断电下确认关节区域无夹手危险（不要擅自硬扳或解除传动）。

**上电**：对照微雪官方《Getting Started Quickly》，检查是否可使用内置网页 UI；不要升级固件或自动中位校准。先做仅一小角度低速动作（例如 5° 量级但以现场机械余量为准），再观察夹爪张合的实际角度方向，保存一份真实串口反馈与固件信息。第一天只在空载/无障碍测试，不进行高速伸展或无人自动执行。

**Python/SDK**（独立 PC 虚拟环境，基于 [官方中文 API](https://github.com/waveshareteam/waveshare_roarm_sdk/blob/d9893632aa7f5a9cb283136ab024faf3143ea7db/doc/roarm_m2_zh.md)）：
\`\`\`python
# 仅用于查询角度；在确认串口、固件和现场许可后再执行
from roarm_sdk.roarm import roarm
arm = roarm(roarm_type="roarm_m2", port="COMx", baudrate=115200)
print(arm.joints_angle_get())
\`\`\`
PC 的 COMx 需换成设备管理器真实端口；不能把 \`COM3\` 或 \`/dev/ttyUSB0\` 当作固定值。查询前关掉 Web 串口占用，避免双客户端竞争。

## 4. Z19 机械臂串口

在 PC 官方控制通过后，先只读 \`lsusb\` / \`dmesg\` / \`/dev/ttyUSB*\`，确认 CP2102 和 baudrate115200。串口 Linux 权限要根据实情处理，**不 chmod 666 任意设备**。Z19 现有 Python3.7 没有可信 pip 配置，不直接安装整份 requirements、ROS2、PyTorch 或重装系统。优先独立最小通信 adapter，有限长度 JSON，超时、串口独占、异常后释放文件描述符，单独发送预定义、边界受限的命令。反馈必须校验字段、范围、序号/时间关联，调试器不能偷偷另开控制串口。

## 5. FPGA 新应用测试与旧 profile 隔离

旧已验 \`MJC1 R2\` 的地址 \`0xA0000000\`，新固件若更改必须通过版本和 profile ID 明确区分；不能混用 \`AHIL\` 的 \`0xA1000000\` 地址。旧 MJC1 R2 不具备真正的舵机输出；仅通过 MMIO 授权接口适配 PS 发送串口命令。新 RTL 的仿真、cdc、DRC、timing/构建和设备兼容报告必须和实际加载的二进制 hash 一致。

**实板加载须另获 Citlali6 明确同意**，先停止所有依赖旧 PL 的用户进程。涉及 IMX214 原相机 profile 时，须按 \`host/camera_linux/README.md\` 先关闭 DMA、确认设备没有映射、驱动卸载，才可以遵循经过审查的加载步骤。不能用未经签收的 \`fpga/camera_hil/\` 实验 bit。

记录：
\`\`\`text
板卡内核/PS profile：
本轮批准人及批准时间：
原 PL profile/恢复路径：
新 bit/bin/XSA SHA256 与 build log：
MMIO 地址和寄存器/协议版本：
进程PID、日志与唯一运动命令来源：
加载、读ID、授权/拒绝、STOP、断链真实结果：
恢复原状态证据：
\`\`\`

## 6. 安全测试顺序

分四层，每层未过不得升到下一层。

- L0 mock：离线无物理动作，合法请求授权、跳序号拒绝、过期拒绝、STOP 锁存、复位需人为同意；测试通过不等于实际机械安全。
- L1 原厂：PC 控制小幅动作+反馈，手动断 RoArm 12V 的风险、重上电安全位置和自检实测；禁止带负载。
- L2 PS/PL：新固件经过 Vivado2020.1 适配/批准后上板，只允许低速小行程与已冻结坐标；注入网络断开、串口断开、迟到消息，观察**不能产生新命令**。
- L3 自动：载轻方块抓取，安全工位和人工监督，不允许有人手进入工作区；记录 STOP 时延时区分“禁新发”“原厂减速/停机”“完全断电”，不编造瞬时停止。

如果发现异常发热、夹爪卡住、底座松动、动作超限、控制失联，现场人员优先断开机械臂独立 12V，保留日志和照片；不得由 Codex 擅自连发“恢复动作”。

## 7. 真实验收数据记录

建议新文件 \`docs/log/2026-10-2X.md\` 和 \`data/metrics/roarm_20261020/\`（需任务分支审批），每条 trial 记录：
\`\`\`text
trial_id, git_head, fpga_bin_sha, roarm_firmware,
camera_source, camera_session, image_seq, calibration_id,
requested_target_table_xy_mm, arm_target_xyz_mm,
stage_start_monotonic, grant_ack, physical_arm_feedback,
pickup_observed, placement_observed, status_reason,
operator, video_log_id
\`\`\`
不要上传包含人脸的真实视频、串口密码或 SSH 密钥；若采集不可匿名化，保留现场并在仓库仅记录匿名元数据/hash。成功率分母覆盖全部启动尝试，不选择性删除失败样本。

## 8. 物理停止的特别边界

本项目采用厂家 ESP32+伺服内环，Z19 PL 只能通过 PS 软件桥授权/拒绝**新**动作。STOP 锁存本身不保证已经向 ESP32 发出的长动作立即停止；厂家 \`torque_set(0)\` 也可能令机械臂失去支撑而下坠。因此：
- 将“停止新动作”“停止伺服运动”“切断供电”视为三个独立结果，各自测试；
- 机械臂底下不摆放人手、易碎物或危险物；
- 断电优先用厂商匹配的可安全操作的插座/开关，现场评估惯性与失力情况；
- 缺乏正式急停硬件和安全认证时，仅限实验室受监管的小质量演示，不面向真人辅助应用。
