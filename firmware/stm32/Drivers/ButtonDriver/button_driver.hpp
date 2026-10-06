#ifndef BUTTON_DRIVER_HPP
#define BUTTON_DRIVER_HPP

#include <stdint.h>

#define DEBOUNCE_COUNT 3  // 3 consecutive reads × 20ms = 60ms debounce

class ButtonDriver {
public:
    enum Event { NONE, PRESSED, RELEASED };

private:
    bool (*read_pin)(void);  // Returns true=high(released), false=low(pressed)
    bool last_confirmed;     // Last confirmed state: true=released, false=pressed
    uint8_t stable_count;

public:
    explicit ButtonDriver(bool (*pin_reader)(void));
    Event Poll();  // Call every 20ms from main loop
};

#endif
