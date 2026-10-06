#ifndef SERVO_WATCHDOG_H
#define SERVO_WATCHDOG_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* HOST 模式下 SERVO_CMD 命令流的失联判定窗口（#179）。
   主循环 20 ms 步长下实际触发点在 100–120 ms。 */
#define SERVO_WATCHDOG_TIMEOUT_MS 100u

typedef struct {
    uint32_t age_ms; /* 距上一条命令的时长，饱和累加 */
} ServoWatchdog;

void ServoWatchdog_Init(ServoWatchdog *wd);
void ServoWatchdog_NoteCommand(ServoWatchdog *wd);
void ServoWatchdog_Tick(ServoWatchdog *wd, uint32_t dt_ms);
uint8_t ServoWatchdog_Expired(const ServoWatchdog *wd);

#ifdef __cplusplus
}
#endif

#endif
