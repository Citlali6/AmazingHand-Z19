// ============================================================================
// stm32_passthrough.ino — SCS 总线透传固件（STM32duino）
//
// 架构：PC(host) ──USB CDC──→ STM32 ──USART1 单线半双工 1Mbps──→ SCS0009 总线
// 协议：帧长前缀 [len][len 字节]；响应同样 [len][bytes]，无响应时 [0]。
//
// 电气：PA9(USART1_TX) 单线半双工引脚 → 总线 DATA（3.3V TTL，SCS0009 兼容）；
//       总线需外部上拉 4.7k（绿板/TXS0108E 侧通常已有）。
//       舵机独立 5V 供电，与 STM32 共地（必须）。
//
// 烧录：Arduino IDE + STM32duino 板包（或 PlatformIO），USB 选中 CDC generic。
// ============================================================================

#define USB_SERIAL Serial     // USB CDC（虚拟串口）
#define BUS_SERIAL Serial1    // PA9/PA10 → 单线半双工

static uint8_t buf[64];

void setup() {
  USB_SERIAL.begin(2000000);  // CDC 波特率仅为标记
  BUS_SERIAL.begin(1000000);
  // 硬件单线半双工：TX 引脚既发又收（发送内容会回听，需在响应收集时跳过）
  BUS_SERIAL.setHalfDuplex();
  USB_SERIAL.println("AH-STM32 passthrough ready");
}

void loop() {
  if (!USB_SERIAL.available()) return;

  uint8_t len = (uint8_t)USB_SERIAL.read();
  if (len == 0 || len > sizeof(buf)) return;  // 无效帧丢弃

  // 读 len 字节（20ms 超时）
  uint32_t t0 = millis();
  uint8_t got = 0;
  while (got < len && millis() - t0 < 20) {
    if (USB_SERIAL.available()) buf[got++] = (uint8_t)USB_SERIAL.read();
  }
  if (got != len) { USB_SERIAL.write((uint8_t)0); return; }

  // 发送到总线
  BUS_SERIAL.write(buf, len);
  BUS_SERIAL.flush();

  // 跳过回听（半双工单线会听到自己发送的 len 字节）
  t0 = millis();
  uint8_t echoed = 0;
  while (echoed < len && millis() - t0 < 10) {
    if (BUS_SERIAL.available()) { BUS_SERIAL.read(); echoed++; }
    else if (!BUS_SERIAL.available() && echoed > 0) break;
  }

  // 收集从机响应：总线静默 3ms 判定结束
  uint8_t rbuf[64];
  uint8_t rn = 0;
  t0 = micros();
  uint32_t last_byte = t0;
  while (micros() - t0 < 15000 && rn < sizeof(rbuf)) {
    if (BUS_SERIAL.available()) {
      rbuf[rn++] = (uint8_t)BUS_SERIAL.read();
      last_byte = micros();
    }
    if (rn > 0 && micros() - last_byte > 3000) break;  // 静默 3ms
  }

  // 回传响应帧
  USB_SERIAL.write((uint8_t)rn);
  if (rn) USB_SERIAL.write(rbuf, rn);
}
