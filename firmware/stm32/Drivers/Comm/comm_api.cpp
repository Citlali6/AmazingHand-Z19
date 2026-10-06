/* Comm 适配层：dt v2 统一帧 + protocols/runtime/c 链路运行时之上，
 * 只保留本演示自己的东西——K1 按键的蓝牙配对策略与 STATE_REPORT 组包。
 * 帧编解码（原 protocol_parser/crc8）与通道仲裁（原 comm_channel/
 * comm_manager）已由生成物和公共运行时取代。 */
#include "comm_api.h"
#include "button_driver.hpp"

#include <new>
#include <string.h>

/* C 对象直接静态持有（无堆、无 placement new） */
static dt_link_t s_link;

/* ButtonDriver 是 C++ 类，构造需要 read_button 适配器，保持 placement new。 */
alignas(ButtonDriver) static unsigned char s_btn_buf[sizeof(ButtonDriver)];
static ButtonDriver *s_btn = nullptr;
static int (*s_read_button)(void) = nullptr;
static bool read_button_adapter(void) { return s_read_button() != 0; }

/* K1 蓝牙配对策略（自 comm_manager 移出）：按下即启用 BT 进入 SEARCHING；
 * 松开满 3 秒仍在 SEARCHING 则放弃 BT 回到串口。 */
#define K1_CONFIRM_US 3000000u
static bool s_k1_held;
static uint32_t s_k1_release_us;

static uint32_t now_us(void) {
    return s_link.ops->now_us();
}

extern "C" void Comm_Init(const dt_link_ops_t *ops, int (*read_button)(void)) {
    const dt_link_config_t cfg = DT_LINK_CONFIG_DEFAULT;
    dt_link_init(&s_link, ops, &cfg);
    s_read_button = read_button;
    s_btn = new (s_btn_buf) ButtonDriver(read_button_adapter);
    s_k1_held = false;
    s_k1_release_us = 0u;
}

/* Called from UART RX interrupt context: lock-free SPSC ring buffer write. */
extern "C" void Comm_Feed(uint8_t ch, const uint8_t *data, uint16_t len) {
    dt_link_feed(&s_link, ch, data, len);
}

extern "C" void Comm_PollButton(void) {
    ButtonDriver::Event evt = s_btn->Poll();
    if (evt == ButtonDriver::PRESSED) {
        s_k1_held = true;
        s_k1_release_us = 0u;
        dt_link_set_bt_enabled(&s_link, 1);
    }
    if (evt == ButtonDriver::RELEASED) {
        s_k1_held = false;
        s_k1_release_us = now_us();
    }
}

extern "C" void Comm_Update(void) {
    dt_link_update(&s_link);
    if (dt_link_state(&s_link) == DT_LINK_SEARCHING && !s_k1_held &&
            s_k1_release_us != 0u &&
            (now_us() - s_k1_release_us) >= K1_CONFIRM_US) {
        dt_link_set_bt_enabled(&s_link, 0);
        s_k1_release_us = 0u;
    }
}

extern "C" void Comm_SendState(uint8_t mode, uint16_t target, uint16_t actual,
                               uint8_t status) {
    dt_state_report_t m;
    uint8_t bitmap[8];
    uint8_t payload[16];
    uint8_t blen = 0u;
    uint16_t plen;
    memset(&m, 0, sizeof m);
    m.mode = mode;
    m.target_angle = target;
    m.actual_angle = actual;
    m.status = status;
    plen = dt_pack_state_report(&m, 0xFu, bitmap, &blen, payload);
    dt_link_send(&s_link, DT_MSG_STATE_REPORT, bitmap, blen, payload, plen);
}

extern "C" int Comm_ExtractFrame(dt_frame_t *frame) {
    return dt_link_pop_frame(&s_link, frame);
}

extern "C" void Comm_RequestReconnectBT(void) {
    dt_link_set_bt_enabled(&s_link, 1);
}

extern "C" dt_link_state_t Comm_LinkState(void) {
    return dt_link_state(&s_link);
}
