#include "servo_watchdog.h"

void ServoWatchdog_Init(ServoWatchdog *wd) {
    wd->age_ms = 0;
}

void ServoWatchdog_NoteCommand(ServoWatchdog *wd) {
    wd->age_ms = 0;
}

void ServoWatchdog_Tick(ServoWatchdog *wd, uint32_t dt_ms) {
    uint32_t room = UINT32_MAX - wd->age_ms;
    wd->age_ms += (dt_ms > room) ? room : dt_ms;
}

uint8_t ServoWatchdog_Expired(const ServoWatchdog *wd) {
    return wd->age_ms > SERVO_WATCHDOG_TIMEOUT_MS;
}
