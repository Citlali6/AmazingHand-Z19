// ============================================================================
// stm32_passthrough.ino — SCS 总线透传固件（江科大 STM32F103C8T6 最小系统板）
//
// 架构：PC(host) ──USART2@115200(经CH340/蓝牙)──→ STM32 ──USART1 单线半双工
//       1Mbps──→ SCS0009 总线（8 舵机树状并联，官方拓扑）
//
// 协议：帧长前缀 [len][len字节]；响应 [len][bytes]，无响应 [0]。
//
// 引脚（F103C8T6）：
//   USART1 TX = PA9  → 单线半双工 → 总线 DATA（白线）
//   USART2 TX = PA2  / RX = PA3 → PC 通道（接 CH340/蓝牙）
//   舵机 5V 独立供电；STM32 GND 与舵机 GND 共地（必须）
//
// 烧录：ST-Link V2（SWD：SWDIO/SWCLK/GND/3V3 四线）+ STM32duino 板包。
//       Arduino IDE → 开发板选 "Generic STM32F1 series" → Board part number
//       "BluePill F103C8" → Upload method: STM32CubeProgrammer(SWD)。
//
// 注意：板载 USB-C 仅供电（数据脚未引出），PC 通信必须走 USART2+CH340。
// ============================================================================

#define PC_SERIAL  Serial2     // PA2/PA3 → CH340/蓝牙 → PC（115200）
#define BUS_SERIAL Serial1     // PA9 单线半双工 → 舵机总线（1Mbps）

static uint8_t buf[64];

void setup() {
  PC_SERIAL.begin(115200);     // PC 通道（蓝牙/CH340 均稳定）
  BUS_SERIAL.begin(1000000);
  BUS_SERIAL.setHalfDuplex();  // 硬件单线半双工：PA9 既发又收（发送内容会回听）
  delay(300);
  PC_SERIAL.println("AH-STM32 passthrough ready (USART2@115200 <-> USART1@1M)");
}

void loop() {
  if (!PC_SERIAL.available()) return;

  uint8_t len = (uint8_t)PC_SERIAL.read();
  if (len == 0 || len > sizeof(buf)) return;  // 无效帧丢弃

  // 读 len 字节（20ms 超时）
  uint32_t t0 = millis();
  uint8_t got = 0;
  while (got < len && millis() - t0 < 20) {
    if (PC_SERIAL.available()) buf[got++] = (uint8_t)PC_SERIAL.read();
  }
  if (got != len) { PC_SERIAL.write((uint8_t)0); return; }

  // 发送到舵机总线
  BUS_SERIAL.write(buf, len);
  BUS_SERIAL.flush();

  // 跳过回听（单线半双工会听到自己发送的 len 字节）
  t0 = millis();
  uint8_t echoed = 0;
  while (echoed < len && millis() - t0 < 10) {
    if (BUS_SERIAL.available()) { BUS_SERIAL.read(); echoed++; }
    else if (echoed > 0) break;
  }

  // 收集从机响应：总线静默 3ms 判定结束（总窗 15ms）
  uint8_t rbuf[64];
  uint8_t rn = 0;
  t0 = micros();
  uint32_t last_byte = t0;
  while (micros() - t0 < 15000 && rn < sizeof(rbuf)) {
    if (BUS_SERIAL.available()) {
      rbuf[rn++] = (uint8_t)BUS_SERIAL.read();
      last_byte = micros();
    }
    if (rn > 0 && micros() - last_byte > 3000) break;
  }

  // 回传响应帧
  PC_SERIAL.write((uint8_t)rn);
  if (rn) PC_SERIAL.write(rbuf, rn);
}
