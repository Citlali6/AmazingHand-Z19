#include "servo_driver.h"
#include "servo_estimator.h"
#include "servo_watchdog.h"
#include "tim.h"

/* Two-tier mode (see issue #141/#142): 0 = knob (board-controlled), 1 = host. */
static uint8_t s_mode = 0;
static ServoEstimator s_estimator;
static ServoWatchdog s_cmd_watchdog;
/* HOST 命令流看门狗触发后锁存，直到下一条带 mode 的合法 SERVO_CMD（#179）。 */
static uint8_t s_error_latched;

void Servo_Init(void) {
    s_mode = 0;
    ServoEstimator_Init(&s_estimator, 90.0f);
    ServoWatchdog_Init(&s_cmd_watchdog);
    s_error_latched = 0;
}

void Servo_SetMode(uint8_t mode) {
    if (mode <= 1) {
        if (mode == 0 && s_mode != 0) {
            // Entering knob mode: re-sync the encoder counter so the knob
            // target starts from the current estimated angle instead of
            // jumping back to the physical knob position.
            uint32_t cnt = (uint32_t)((ServoEstimator_GetAngle(&s_estimator) / SERVO_ANGLE_MAX)
                                      * (float)SERVO_KNOB_COUNT_MAX);
            __HAL_TIM_SET_COUNTER(&htim1, cnt);
        }
        s_mode = mode;
    }
}

uint8_t Servo_GetMode(void) {
    return s_mode;
}

void Servo_SetTarget(float angle) {
    ServoEstimator_SetTarget(&s_estimator, angle);
}

float Servo_GetTarget(void) {
    return ServoEstimator_GetTarget(&s_estimator);
}

/* 本演示无输出轴传感器；返回 36 deg/s 限速模型的软件估计反馈。 */
float Servo_GetActual(void) {
    return ServoEstimator_GetAngle(&s_estimator);
}

void Servo_NoteCommand(void) {
    ServoWatchdog_NoteCommand(&s_cmd_watchdog);
}

void Servo_AckModeCommand(void) {
    s_error_latched = 0;
}

uint8_t Servo_GetErrorLatched(void) {
    return s_error_latched;
}

void Servo_Update(float dt_ms) {
    if (s_mode == 1) {
        ServoWatchdog_Tick(&s_cmd_watchdog, (uint32_t)dt_ms);
        if (ServoWatchdog_Expired(&s_cmd_watchdog)) {
            /* HOST 命令流失联：无扰切回 KNOB（旋钮重同步到当前估计角），
               锁存 ERROR 直到下一条带 mode 的合法 SERVO_CMD。 */
            Servo_SetMode(0);
            s_error_latched = 1;
            ServoWatchdog_NoteCommand(&s_cmd_watchdog);
        }
    }

    if (s_mode == 0) {
        // Knob mode: read encoder and map to 0-180
        int count = __HAL_TIM_GET_COUNTER(&htim1);
        if (count > SERVO_KNOB_UNDERFLOW_THRESHOLD) {
            // 16-bit counter underflow: knob turned backward past zero.
            count = 0;
            __HAL_TIM_SET_COUNTER(&htim1, 0);
        }
        if (count < 0) count = 0;
        if (count > SERVO_KNOB_COUNT_MAX) count = SERVO_KNOB_COUNT_MAX;
        ServoEstimator_SetTarget(
            &s_estimator,
            ((float)count / SERVO_KNOB_COUNT_MAX) * SERVO_ANGLE_MAX);
    }

    ServoEstimator_Update(&s_estimator, dt_ms);

    // PWM: 0° -> CCR=50, 180° -> CCR=250
    uint16_t ccr = (uint16_t)(50.0f +
        (ServoEstimator_GetAngle(&s_estimator) / SERVO_ANGLE_MAX) * 200.0f);
    __HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_3, ccr);
}
