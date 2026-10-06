#ifndef SERVO_ESTIMATOR_H
#define SERVO_ESTIMATOR_H

#ifdef __cplusplus
extern "C" {
#endif

#define SERVO_ESTIMATOR_ANGLE_MIN 0.0f
#define SERVO_ESTIMATOR_ANGLE_MAX 180.0f
#define SERVO_ESTIMATOR_MAX_RATE_DEG_PER_S 36.0f

typedef struct {
    float target_angle;
    float estimated_angle;
} ServoEstimator;

void ServoEstimator_Init(ServoEstimator *estimator, float initial_angle);
void ServoEstimator_SetTarget(ServoEstimator *estimator, float target_angle);
void ServoEstimator_Update(ServoEstimator *estimator, float dt_ms);
float ServoEstimator_GetTarget(const ServoEstimator *estimator);
float ServoEstimator_GetAngle(const ServoEstimator *estimator);

#ifdef __cplusplus
}
#endif

#endif
