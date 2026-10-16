// SPDX-License-Identifier: GPL-2.0
/* Camera-0 bench driver for bit SHA256 28e1e3e7963ff12f57848998cf2695dcca139c3f519c5f020daf90dec4dc35ae.
 * DMA allocation follows the supplied ALINX mipi_cam.c. This driver owns VDMA
 * start/stop and maps coherent buffers through the DMA API, not /dev/mem.
 * Load only after checking firmware hash, clocks, HP1 width and idle PL users.
 * No automatic boot loading. No hand-control registers are accessed.
 */
#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/dma-mapping.h>
#include <linux/of_device.h>
#include <linux/mm.h>
#include <linux/io.h>
#include <linux/iopoll.h>
#include <linux/delay.h>
#include <linux/uaccess.h>
#include <linux/mutex.h>
#include "ah_camera0_uapi.h"

#define WIDTH 1920U
#define HEIGHT 1080U
#define FRAME_BYTES (WIDTH * HEIGHT * 3U)
#define BUFFERS 3U
#define VDMA_BASE 0xa0060000UL
#define GPIO_BASE 0xa0080000UL
#define CR 0x30
#define SR 0x34
#define ERROR_BITS 0xff0U

static bool matched_pl;
module_param(matched_pl, bool, 0400);
MODULE_PARM_DESC(matched_pl, "Explicit acknowledgement of verified camera PL profile");
static void __iomem *vdma, *gpio;
static void *frames;
static dma_addr_t dma_base;
static size_t stride, map_bytes;
static u64 dma_mask = DMA_BIT_MASK(32);
static bool opened;
static DEFINE_MUTEX(camera_lock);

/* Reset CSI/sensor first on close, then halt/reset VDMA. Never free active DMA. */
static int stop_dma(void)
{
	u32 value;
	writel(0, gpio);
	writel(readl(vdma + CR) & ~1U, vdma + CR);
	if (!readl_poll_timeout(vdma + SR, value, value & 1, 100, 200000))
		return 0;
	writel(4, vdma + CR);
	if (readl_poll_timeout(vdma + CR, value, !(value & 4), 100, 200000))
		return -ETIMEDOUT;
	return readl_poll_timeout(vdma + SR, value, value & 1, 100, 200000);
}

static int camera_open(struct inode *inode, struct file *file)
{
	int ret = 0;
	mutex_lock(&camera_lock);
	if (opened)
		ret = -EBUSY;
	else
		opened = true;
	mutex_unlock(&camera_lock);
	return ret;
}

static int camera_release(struct inode *inode, struct file *file)
{
	int ret;
	mutex_lock(&camera_lock);
	ret = stop_dma();
	if (ret)
		pr_crit("ah_camera0: DMA failed to halt; buffers remain allocated\n");
	else
		opened = false;
	mutex_unlock(&camera_lock);
	return ret;
}

static long camera_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct ah_camera0_info info = {0};
	struct ah_camera0_status status;
	u32 value;
	int ret = 0, i;
	mutex_lock(&camera_lock);
	switch (cmd) {
	case AH_CAM_INFO:
		for (i = 0; i < BUFFERS; i++)
			info.dma_addr[i] = dma_base + i * stride;
		info.frame_bytes = FRAME_BYTES;
		info.buffer_stride = stride;
		info.map_bytes = map_bytes;
		info.width = WIDTH;
		info.height = HEIGHT;
		info.buffers = BUFFERS;
		info.abi_version = 1;
		ret = copy_to_user((void __user *)arg, &info, sizeof(info)) ? -EFAULT : 0;
		break;
	case AH_CAM_START:
		if (!(readl(vdma + SR) & 1)) { ret = -EBUSY; break; }
		writel(4, vdma + CR);
		ret = readl_poll_timeout(vdma + CR, value, !(value & 4), 100, 200000);
		if (ret) break;
		memset(frames, 0, map_bytes);
		writel(0xfff0, vdma + SR);
		writel(0, vdma + 0x44);
		/* Raw configurable c_num_fstores=3; derived C_NUM_FSTORES=6 is stale.
		 * Fill all six address pairs with owned memory as a defensive measure. */
		for (i = 0; i < 6; i++) {
			u64 addr = dma_base + (i % BUFFERS) * stride;
			writel(lower_32_bits(addr), vdma + 0xac + i * 8);
			writel(upper_32_bits(addr), vdma + 0xb0 + i * 8);
		}
		writel(WIDTH * 3, vdma + 0xa4);
		writel(WIDTH * 3, vdma + 0xa8);
		/* Continuous circular mode, stream TUSER SOF, no IRQ enable. */
		writel(0x00010043, vdma + CR);
		writel(HEIGHT, vdma + 0xa0);
		break;
	case AH_CAM_STOP:
		ret = stop_dma();
		break;
	case AH_CAM_STATUS:
		status.control = readl(vdma + CR);
		status.status = readl(vdma + SR);
		status.write_index = (readl(vdma + 0x28) >> 24) & 31;
		status.version = readl(vdma + 0x2c);
		ret = copy_to_user((void __user *)arg, &status, sizeof(status)) ? -EFAULT : 0;
		break;
	case AH_CAM_CLEAR:
		writel(0xfff0, vdma + SR);
		break;
	default:
		ret = -ENOTTY;
	}
	mutex_unlock(&camera_lock);
	return ret;
}

static int camera_mmap(struct file *file, struct vm_area_struct *vma)
{
	if (vma->vm_pgoff || vma->vm_end - vma->vm_start != map_bytes ||
	    vma->vm_flags & VM_WRITE || !(vma->vm_flags & VM_MAYSHARE))
		return -EINVAL;
	vma->vm_flags &= ~VM_MAYWRITE;
	vma->vm_flags |= VM_DONTEXPAND | VM_DONTDUMP;
	return dma_mmap_coherent(file->private_data ?
		((struct miscdevice *)file->private_data)->this_device : NULL,
		vma, frames, dma_base, map_bytes);
}

static const struct file_operations camera_fops = {
	.owner = THIS_MODULE,
	.open = camera_open,
	.release = camera_release,
	.unlocked_ioctl = camera_ioctl,
	.mmap = camera_mmap,
	.llseek = no_llseek,
};

static struct miscdevice camera_misc = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "ah_camera0",
	.fops = &camera_fops,
	.mode = 0600,
};

static int __init camera_init(void)
{
	struct device *dev;
	int ret;
	if (!matched_pl) return -EPERM;
	vdma = ioremap(VDMA_BASE, 4096);
	gpio = ioremap(GPIO_BASE, 4096);
	if (!vdma || !gpio) { ret = -ENOMEM; goto unmap; }
	if (readl(vdma + 0x2c) != 0x62000050) { ret = -ENODEV; goto unmap; }
	ret = stop_dma();
	if (ret) goto unmap;
	ret = misc_register(&camera_misc);
	if (ret) goto unmap;
	dev = camera_misc.this_device;
	dev->dma_mask = &dma_mask;
	ret = of_dma_configure(dev, NULL, true);
	if (ret) goto deregister;
	ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(32));
	if (ret) goto deregister;
	stride = PAGE_ALIGN(FRAME_BYTES);
	map_bytes = stride * BUFFERS;
	frames = dma_alloc_coherent(dev, map_bytes, &dma_base, GFP_KERNEL);
	if (!frames) { ret = -ENOMEM; goto deregister; }
	memset(frames, 0, map_bytes);
	pr_info("ah_camera0: %u x %u RGB, %u buffers, DMA=0x%llx map=%zu\n",
		WIDTH, HEIGHT, BUFFERS, (unsigned long long)dma_base, map_bytes);
	return 0;
deregister:
	misc_deregister(&camera_misc);
unmap:
	if (gpio) iounmap(gpio);
	if (vdma) iounmap(vdma);
	return ret;
}

static void __exit camera_exit(void)
{
	if (stop_dma())
		pr_crit("ah_camera0: refusing to free unhalted DMA memory; power cycle required\n");
	else
		dma_free_coherent(camera_misc.this_device, map_bytes, frames, dma_base);
	misc_deregister(&camera_misc);
	iounmap(gpio);
	iounmap(vdma);
}

module_init(camera_init);
module_exit(camera_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("AmazingHand reviewed Z19 camera-0 bench capture");
MODULE_AUTHOR("AmazingHand; allocation reference ALINX mipi_cam.c");
