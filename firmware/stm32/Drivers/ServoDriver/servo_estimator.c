#include "servo_estimator.h"

static float clamp_angle(float value) {
    if (value < SERVO_ESTIMATOR_ANGLE_MIN) return SERVO_ESTIMATOR_ANGLE_MIN;
    if (value > SERVO_ESTIMATOR_ANGLE_MAX) return SERVO_ESTIMATOR_ANGLE_MAX;
    return value;
}

void ServoEstimator_Init(ServoEstimator *estimator, float initial_angle) {
    const float angle = clamp_angle(initial_angle);
    estimator->target_angle = angle;
    estimator->estimated_angle = angle;
}

void ServoEstimator_SetTarget(ServoEstimator *estimator, float target_angle) {
    estimator->target_angle = clamp_angle(target_angle);
}

void ServoEstimator_Update(ServoEstimator *estimator, float dt_ms) {
    const float max_delta = SERVO_ESTIMATOR_MAX_RATE_DEG_PER_S * dt_ms / 1000.0f;
    float delta = estimator->target_angle - estimator->estimated_angle;
    if (delta > max_delta) delta = max_delta;
    if (delta < -max_delta) delta = -max_delta;
    estimator->estimated_angle = clamp_angle(estimator->estimated_angle + delta);
}

float ServoEstimator_GetTarget(const ServoEstimator *estimator) {
    return estimator->target_angle;
}

float ServoEstimator_GetAngle(const ServoEstimator *estimator) {
    return estimator->estimated_angle;
}
