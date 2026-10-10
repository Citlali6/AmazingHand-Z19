obj-m := ah_camera0.o

KERNEL_DIR ?= /lib/modules/$(shell uname -r)/build

.PHONY: module capture
module:
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE= HOSTCC=gcc M=$(CURDIR) modules

capture:
	$(CC) -std=c11 -O2 -Wall -Wextra -Werror -pthread -o capture_camera0 capture_camera0.c camera_preview.c -ljpeg
