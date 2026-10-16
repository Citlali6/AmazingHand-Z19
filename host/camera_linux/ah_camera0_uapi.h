/* Fixed-width bench ABI; this device supports only the reviewed camera-0 PL. */
#ifndef AH_CAMERA0_UAPI_H
#define AH_CAMERA0_UAPI_H
#include <linux/types.h>
#include <linux/ioctl.h>

struct ah_camera0_info {
	__u64 dma_addr[3];
	__u32 frame_bytes;
	__u32 buffer_stride;
	__u32 map_bytes;
	__u32 width;
	__u32 height;
	__u32 buffers;
	__u32 abi_version;
	__u32 reserved;
};

struct ah_camera0_status {
	__u32 control;
	__u32 status;
	__u32 write_index;
	__u32 version;
};

#define AH_CAM_INFO _IOR('A', 1, struct ah_camera0_info)
#define AH_CAM_START _IO('A', 2)
#define AH_CAM_STOP _IO('A', 3)
#define AH_CAM_STATUS _IOR('A', 4, struct ah_camera0_status)
#define AH_CAM_CLEAR _IO('A', 5)
#endif
