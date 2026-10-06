#ifndef SERVO_DRIVER_H
#define SERVO_DRIVER_H

#include <stdint.h>

#define SERVO_ANGLE_MIN 0.0f
#define SERVO_ANGLE_MAX 180.0f
#define SERVO_KNOB_COUNT_MAX 20
/* Encoder underflow threshold: 16-bit TIM1 counter wraps to ~65535 when
   the knob is turned backward past zero. Valid counts stay within 0..20,
   so anything above this threshold is treated as underflow and clamped to 0. */
#define SERVO_KNOB_UNDERFLOW_THRESHOLD 6000

void Servo_Init(void);
void Servo_SetMode(uint8_t mode);
uint8_t Servo_GetMode(void);
void Servo_SetTarget(float angle);
float Servo_GetTarget(void);
/* 本演示无输出轴传感器；返回 36 deg/s 限速模型的软件估计反馈。 */
float Servo_GetActual(void);
void Servo_Update(float dt_ms);
/* HOST 模式命令流看门狗（#179）：任何 SERVO_CMD 刷新；超时切 KNOB 并锁存
   ERROR，锁存只被下一条带 mode 的合法 SERVO_CMD 清除。 */
void Servo_NoteCommand(void);
void Servo_AckModeCommand(void);
uint8_t Servo_GetErrorLatched(void);

#endif
