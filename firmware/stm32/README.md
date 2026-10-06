# firmware/stm32 — AmazingHand 宿舍测试台透传固件

STM32F103C8T6（江协科技最小系统板）作为 SCS 总线透传网关：PC 端
AmazingHand host（host/app/control/backend_mcu.py + golden model
scs_protocol.py）经 ST-Link VCP 下发原始 SCS 帧字节，本固件将其泵到
1 Mbps 半双工总线上驱动 8 个 SCS0009。

架构定位：宿舍测试台下位机（实验室 Z19 不可用时）。正式 1kHz 实时环
在 Z19 PL（fpga/rtl/）。本固件只做字节泵，协议语义全部在 PC 端
golden model——两侧对照基准唯一。

## 拓扑

PC (host) -- /dev/ttyACM0 @115200（ST-Link VCP）--> USART2 PA2/PA3
-- 透传（帧长前缀协议）--> USART1 PA9 单线半双工 @1Mbps
--> 8 x SCS0009（Feetech SCS-Y4 分线板树状并联 = 单总线）

协议：下行 [len u8][len 字节 SCS 帧]；上行 [len][字节]，len=0 表示
总线静默（舵机无响应或离线）。半双工回听由固件丢弃。

## 接线（必须遵守）

| 信号 | 从 | 到 |
|---|---|---|
| 总线 DATA（白） | 最终 3pin 口 | STM32 PA9 |
| 总线 GND（黑） | 最终 3pin 口 | 5V 电源负极 且 STM32 GND（共地，必须） |
| 总线 V+（红） | 最终 3pin 口 | 独立 5V 电源正极，禁止从板或 USB 取电 |

## 构建（Ubuntu 22.04，工具链 arm-none-eabi-gcc）

    cd firmware/stm32
    cmake --preset Debug
    cmake --build build/Debug
    # 产物：build/Debug/ah_passthrough.elf

工具链缺失时：sudo apt install gcc-arm-none-eabi cmake（或安装
STM32CubeIDE for VSCode 扩展自带的工具链，与 demos 模板一致）。

## 烧录（ST-Link V2 SWD）

    STM32_Programmer_CLI -c port=SWD freq=4000 -w build/Debug/ah_passthrough.elf -v -rst

SWD 四线：SWDIO/SWCLK/GND/3V3。板载 USB-C 仅供电。

## 联调

    python tools/probe_servos.py --port /dev/ttyACM0
    # 控制台换真手后端：host/config/settings.yaml 改 backend: mcu

backend_mcu.py 的帧协议与本固件一一对应。

## 故障排查

| 现象 | 排查顺序 |
|---|---|
| probe 全部无响应 | 共地 / 5V 供电 / PA9 接线 / 舵机 ID 是否 1-8 |
| 响应偶发校验错 | GND 走线 / 1Mbps 信号完整性（杜邦线尽量短） |
| /dev/ttyACM0 缺失 | ST-Link 驱动 / 重新插拔 / lsusb 查 ST-LINK VID |

- 工具链：`arm-none-eabi-gcc`（编译环境见 [docs/ENVIRONMENT.md](../../../docs/ENVIRONMENT.md)）
- 构建与烧录：`cmake --preset Debug && cmake --build build/Debug`，
  烧录用 STM32CubeProgrammer（流程见 [docs/ENVIRONMENT.md](../../../docs/ENVIRONMENT.md)）
- 帧协议：dt 统一帧 v2（`protocols/` 为权威，固件直接引用
  `protocols/generated/c` + `protocols/runtime/c`）
  - `SERVO_CMD`（主机→板）：mode（0=旋钮/板子自控，1=主机控）+
    target_angle（0.1° 单位）；字段可按位图缺省
  - `STATE_REPORT`（板→主机，50Hz）：mode / target / actual（0.1° 单位，actual 为软件估计）/ status
  - `LED_CMD`、`RECONNECT_BT`、心跳由链路运行时与公共分支处理
- 舵机驱动 `Drivers/ServoDriver`：`servo_estimator` 以 20ms 步长计算 36°/s 限速估计反馈；旋钮（TIM1 编码器）0..20 计数
  映射 0..180°；进入旋钮模式时编码器计数重同步到当前实际角，避免跳变
- 主机测试：`Tests/`（`test_comm_api` 覆盖协议适配，`test_servo_estimator` 覆盖估计反馈的限速、限位和收敛）

源码结构：`Drivers/ServoDriver`（限速模型 + 旋钮 + PWM）+
`Drivers/Comm`（dt v2 适配层）+ `Core/Src/main.c`（20ms 主循环）。
