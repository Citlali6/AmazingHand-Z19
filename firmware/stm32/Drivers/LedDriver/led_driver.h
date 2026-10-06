#ifndef LED_DRIVER_H
#define LED_DRIVER_H

#include <stdint.h>

void Led_Init(void);
void Led_Set(uint8_t r, uint8_t g, uint8_t b);

#endif
