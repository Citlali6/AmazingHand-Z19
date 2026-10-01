# Z19 开发板关键规格摘录（面向本项目）

> 来源：《Z19 用户手册.pdf》（ALINX，57 页，2026-09-30 提取）
> 用途：`fpga/constr/z19.xdc` 约束、端口规划、电平约束快速查表；引脚号均实测自手册原文
> 配套：物理层设计决策见 `docs/design/interface.md` §2

## 1. 主控与存储

- 芯片：`XCZU19EG-2FFVC1760I`（Zynq UltraScale+ MPSoC，4×Cortex-A53 + R5F + PL）
- PS DDR4：8GB（4×Micron MT40A1G16KD，64bit，BANK504）
- PL DDR4：SODIMM 插槽（BANK69/70/71，**本项目不用**）
- 板载存储：QSPI 512Mb + eMMC（均 BANK500）、TF 卡槽（BANK501，启动用）

## 2. 时钟（xdc 必用）

| 信号 | 引脚 | 说明 |
|---|---|---|
| `PL_CLK0_P` | H24 | 差分 200MHz，BANK64 MRCC |
| `PL_CLK0_N` | G25 | → MMCM 生成 100MHz `ctrl_clk`（控制环） |
| `PS_REF_CLK` | AC27 | PS 33.333MHz |

## 3. PL IO 电平约束（关键结论）

- **Z19 全部 PL IO 位于 HP bank，VCCO 最高 1.8V，无 3.3V 能力**
- FMC1（BANK67/68）：跳帽 **J5** 选 1.8V / 1.2V → 本项目**置 1.8V**
- FMC2（BANK64/65/66）：跳帽 **J88** 选 1.8V / 1.2V
- 推论：接 5V TTL 舵机必须经电平转换（TXS0108E 方案见 interface.md §2.2）

## 4. FMC1 引脚分配表（xdc 主查表）

36 对差分 IO（LA00~LA33 + 2 对时钟），单端使用时借 P 脚。**BANK68：LA00~LA16；BANK67：LA17~LA33**。

| FMC 信号 | P 脚 | N 脚 | Bank | 本项目用途 |
|---|---|---|---|---|
| FMC1_CLK0 | F14 | E14 | 68 | — |
| FMC1_CLK1 | AT11 | AT10 | 67 | — |
| FMC1_LA00_CC | G17 | F17 | 68 | — |
| FMC1_LA01_CC | G16 | F15 | 68 | — |
| **FMC1_LA02** | **L17** | **K17** | 68 | **P=SERVO_DATA（主总线）；N=预留第二总线** |
| FMC1_LA03 | A14 | A13 | 68 | 预留（扩第二总线备选区） |
| FMC1_LA04 | B18 | A18 | 68 | — |
| FMC1_LA05 | B13 | A12 | 68 | — |
| FMC1_LA06 | E17 | D17 | 68 | — |
| FMC1_LA07 | D18 | C18 | 68 | — |
| FMC1_LA08 | B17 | A17 | 68 | — |
| FMC1_LA09 | C16 | B16 | 68 | — |
| FMC1_LA10 | D13 | C13 | 68 | — |
| FMC1_LA11 | M15 | L15 | 68 | — |
| FMC1_LA12 | E16 | D16 | 68 | — |
| FMC1_LA13 | K16 | K15 | 68 | — |
| FMC1_LA14 | P15 | N15 | 68 | — |
| FMC1_LA15 | P16 | N16 | 68 | — |
| FMC1_LA16 | M17 | M16 | 68 | — |
| FMC1_LA17_CC | AR13 | AR12 | 67 | — |
| FMC1_LA18_CC | AT13 | AT12 | 67 | — |
| FMC1_LA19 | AR15 | AR14 | 67 | — |
| FMC1_LA20 | AJ14 | AK14 | 67 | — |
| FMC1_LA21 | AL14 | AM14 | 67 | — |
| FMC1_LA22 | AJ15 | AK15 | 67 | — |
| FMC1_LA23 | AM13 | AN13 | 67 | — |
| FMC1_LA24 | AW11 | AW10 | 67 | — |
| FMC1_LA25 | AP10 | AR10 | 67 | — |
| FMC1_LA26 | AL15 | AM15 | 67 | — |
| FMC1_LA27 | AN14 | AP14 | 67 | — |
| FMC1_LA28 | AV9 | AV8 | 67 | — |
| FMC1_LA29 | AW9 | AY9 | 67 | — |
| FMC1_LA30 | BB9 | BB8 | 67 | — |
| FMC1_LA31 | AW8 | AY8 | 67 | — |
| FMC1_LA32 | BA6 | BB6 | 67 | — |
| FMC1_LA33 | BA8 | BA7 | 67 | — |
| FMC1_SDA / SCL | A4 / B6 | — | 94 | FMC I2C（EEPROM），本项目不用 |

FMC1 另有 8 组 GTH 收发器（BANK230/231，DP0~DP7），本项目不用。
FMC2：60 对差分（BANK64/65/66，J88 跳帽），本项目预留不用；完整表查原手册。

## 5. 板载调试资源

| 信号 | 引脚 | Bank | 说明 |
|---|---|---|---|
| `PL_LED1` | B3 | 94 | 用户 PL LED（本项目：1Hz 心跳） |
| `PL_KEY` | D4 | 94 | 用户 PL 按键，**低电平有效**（本项目：急停 ESTOP_N，RTL 内上拉+消抖） |
| `PL_UART_TX` | C3 | 94 | 经 CP2102GM → mini USB（PC 调试通道） |
| `PL_UART_RX` | C6 | 94 | 同上 |
| `PS_LED1` | MIO42（T30） | 501 | 用户 PS LED |
| `PS_KEY` | MIO26（L27） | 501 | 用户 PS 按键 |

注意：PL/PS bank 电平均为 1.8V 系（PL_UART 经 CP2102 1.8V VIO 直连）。

## 6. PS 侧外设端口（host 应用接入）

| 外设 | 数量/引脚 | 本项目用途 |
|---|---|---|
| USB3.0 HOST | 4 口（PS USB3.0 PIPE3 + USB3320C ULPI） | USB 相机（`/dev/video0`）、USB 麦克风（ALSA）、USB-TTL Waveshare 驱动板（软件环 `/dev/ttyUSB0`） |
| 千兆以太网 | 2 路（PS：KSZ9031RNX RGMII MIO64~75；PL：BANK64） | SSH 部署走 PS 口；PL 网口不用 |
| UART | 3 路：PS UART1（MIO38/39）与 PL UART（C3/C6）均经 CP2102 转 mini USB；PS UART2（MIO32/33）经 10pin FPC 引出 | 串口调试 |
| HDMI / mini_DP / M.2 / SATA×4 / QSFP28×4 / PCIE / CAN×2 / RS485×2 / MIPI 摄像头 / 3 对 SMA | — | 本项目均不用（检测用 USB 相机，不用 MIPI） |

## 7. 启动模式（SW1 拨码，位序 4-3-2-1）

| SW1（4,3,2,1） | MODE[3:0] | 启动模式 | 本项目场景 |
|---|---|---|---|
| ON, ON, ON, ON | 0000 | JTAG | Vivado 烧 bit / 调试 |
| ON, ON, OFF, ON | 0010 | QSPI FLASH | — |
| ON, OFF, ON, OFF | 0101 | SD 卡 | **烧 ALINX Ubuntu 镜像后的日常启动** |
| ON, OFF, OFF, ON | 0110 | eMMC | 备选 |

## 8. 供电与散热

- 输入：DC 12V；板内产生 +5V / +3.3V / +1.8V 等
- 芯片散热：出厂带散热片+风扇（J62 插座，BANK94 IO 高电平开启 MOSFET）
- **舵机供电：外置 5V/2A 适配器（官方 BOM），严禁从 VADJ/FMC 取电**

## 9. EEPROM / 温度传感器（BANK501 I2C）

- PS_IIC1_SCL = MIO24（AH33），PS_IIC1_SDA = MIO25（AG34）
- LM75 板温传感器 + EEPROM，系统占用，host 勿重复驱动
