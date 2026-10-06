#include "button_driver.hpp"

ButtonDriver::ButtonDriver(bool (*pin_reader)(void))
    : read_pin(pin_reader), last_confirmed(true), stable_count(0) {}

ButtonDriver::Event ButtonDriver::Poll() {
    bool current = read_pin();

    if (current == last_confirmed) {
        stable_count = 0;
        return NONE;
    }

    stable_count++;
    if (stable_count >= DEBOUNCE_COUNT) {
        stable_count = 0;
        last_confirmed = current;
        if (current == false) {
            return PRESSED;   // Transitioned to low = pressed
        } else {
            return RELEASED;  // Transitioned to high = released
        }
    }
    return NONE;
}
