#ifndef CAMERA_PREVIEW_H
#define CAMERA_PREVIEW_H
#include <stdint.h>
#include "ah_camera0_uapi.h"
int camera_preview(const char *dir, int fd, const uint8_t *frames,
                   const struct ah_camera0_info *info, unsigned *sequence);
void camera_preview_shutdown(void);
#endif
