#include "led_driver.h"
#include "main.h"

void Led_Init(void) {
    Led_Set(0, 0, 0);
}

void Led_Set(uint8_t r, uint8_t g, uint8_t b) {
    HAL_GPIO_WritePin(LED_RED_GPIO_Port, LED_RED_Pin,
                      r ? GPIO_PIN_SET : GPIO_PIN_RESET);
    HAL_GPIO_WritePin(LED_GREEN_GPIO_Port, LED_GREEN_Pin,
                      g ? GPIO_PIN_SET : GPIO_PIN_RESET);
    HAL_GPIO_WritePin(LED_BLUE_GPIO_Port, LED_BLUE_Pin,
                      b ? GPIO_PIN_SET : GPIO_PIN_RESET);
}
