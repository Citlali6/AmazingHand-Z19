/* Linux port of the already validated Z19 CAM0 bare-metal sequence.
 * Usage: capture_camera0 SECONDS OUTPUT.raw [FOCUS_POSITION [NEW_PREVIEW_DIR]]
 * A normal exit stops sensor/VDMA before saving and unmapping. Existing output
 * is never overwritten. The supplied register table must be copied alongside.
 */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include "ah_camera0_uapi.h"
#include "sensor_table.h"
#include "camera_preview.h"

static volatile sig_atomic_t quitting;
static void on_signal(int sig) { (void)sig; quitting = 1; }
static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}
static void delay_ms(unsigned ms) {
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
    while (nanosleep(&ts, &ts) && errno == EINTR && !quitting) {}
}
static int transfer(int fd, struct i2c_msg *msgs, unsigned count) {
    struct i2c_rdwr_ioctl_data data = { .msgs = msgs, .nmsgs = count };
    int ret = ioctl(fd, I2C_RDWR, &data);
    if (ret != (int)count) { perror("I2C_RDWR"); return -1; }
    return 0;
}
static int sensor_write(int fd, unsigned reg, unsigned value) {
    uint8_t bytes[3] = { reg >> 8, reg & 255, value };
    struct i2c_msg msg = { .addr = 0x10, .len = 3, .buf = bytes };
    int ret = transfer(fd, &msg, 1);
    delay_ms(1);
    return ret;
}
static int sensor_read(int fd, unsigned reg, uint8_t *value) {
    uint8_t addr[2] = { reg >> 8, reg & 255 };
    struct i2c_msg msgs[2] = {
        { .addr = 0x10, .len = 2, .buf = addr },
        { .addr = 0x10, .flags = I2C_M_RD, .len = 1, .buf = value }
    };
    return transfer(fd, msgs, 2);
}
static int set_focus(int fd, unsigned position) {
    uint8_t bytes[2] = { position >> 4, (position & 15) << 4 };
    struct i2c_msg msg = { .addr = 0x0c, .len = 2, .buf = bytes };
    return transfer(fd, &msg, 1);
}
static uint32_t sample_hash(const uint8_t *frame, unsigned bytes, unsigned *nonzero) {
    uint32_t value = 2166136261U;
    *nonzero = 0;
    for (unsigned p = 0; p < bytes; p += 5009) {
        value = (value ^ frame[p]) * 16777619U;
        *nonzero += frame[p] != 0;
    }
    return value;
}
static int write_frame(const char *path, const uint8_t *frame, unsigned bytes) {
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0) { perror("create raw frame"); return -1; }
    unsigned written = 0;
    while (written < bytes) {
        ssize_t result = write(fd, frame + written, bytes - written);
        if (result < 0 && errno == EINTR) continue;
        if (result <= 0) { perror("write raw frame"); close(fd); return -1; }
        written += result;
    }
    int ret = fsync(fd);
    if (close(fd) && !ret) ret = -1;
    return ret;
}
int main(int argc, char **argv) {
    struct ah_camera0_info info = {0};
    struct ah_camera0_status status = {0};
    int camera = -1, i2c = -1, mem = -1, ret = 1, started = 0, valid = 0;
    uint8_t *frames = MAP_FAILED;
    volatile uint32_t *gpio = MAP_FAILED, *gamma = MAP_FAILED;
    unsigned seconds, focus = 300, changes = 0, last_changes = 0, seen = 0, preview_sequence = 0;
    uint8_t hi, lo, wh, wl, hh, hl;
    char *end;
    if (argc < 3 || argc > 5) { fprintf(stderr, "usage: %s SECONDS NEW_OUTPUT.raw [FOCUS_0_1023 [NEW_PREVIEW_DIR]]\n", argv[0]); return 2; }
    unsigned long duration = strtoul(argv[1], &end, 10);
    if (!*argv[1] || *end || duration < 1 || duration > 3600) return 2;
    seconds = duration;
    if (argc >= 4) {
        unsigned long position = strtoul(argv[3], &end, 10);
        if (!*argv[3] || *end || position > 1023) return 2;
        focus = position;
    }
    if (access(argv[2], F_OK) == 0) { fprintf(stderr, "output exists; refusing overwrite\n"); return 2; }
    if (argc == 5 && mkdir(argv[4], 0700)) { perror("new preview directory"); return 2; }
    setvbuf(stdout, NULL, _IOLBF, 0);
    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);
    pid_t parent = getppid();
    camera = open("/dev/ah_camera0", O_RDONLY | O_CLOEXEC);
    if (camera < 0) { perror("open camera"); goto done; }
    if (ioctl(camera, AH_CAM_INFO, &info)) { perror("buffer info"); goto done; }
    if (info.abi_version != 1 || info.width != 1920 || info.height != 1080 ||
        info.buffers != 3 || info.frame_bytes != 6220800 ||
        info.buffer_stride < info.frame_bytes || info.map_bytes != info.buffer_stride * 3) goto done;
    frames = mmap(NULL, info.map_bytes, PROT_READ, MAP_SHARED, camera, 0);
    if (frames == MAP_FAILED) { perror("map DMA buffers"); goto done; }
    printf("BUFFERS 0x%" PRIx64 " 0x%" PRIx64 " 0x%" PRIx64 " stride=%u bytes=%u\n",
           (uint64_t)info.dma_addr[0], (uint64_t)info.dma_addr[1], (uint64_t)info.dma_addr[2], info.buffer_stride, info.map_bytes);
    mem = open("/dev/mem", O_RDWR | O_SYNC | O_CLOEXEC);
    if (mem < 0) { perror("open registers"); goto done; }
    gpio = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, mem, 0xa0080000);
    gamma = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, mem, 0xa0040000);
    if (gpio == MAP_FAILED || gamma == MAP_FAILED) { perror("map registers"); goto done; }
    gpio[1] = 0; gpio[0] = 0; delay_ms(20); gpio[0] = 3; delay_ms(20);
    i2c = open("/dev/i2c-0", O_RDWR | O_CLOEXEC);
    if (i2c < 0) { perror("open I2C0"); goto done; }
    if (sensor_read(i2c, 0x16, &hi) || sensor_read(i2c, 0x17, &lo)) goto done;
    printf("CAM0_SENSOR_ID 0x%02x%02x\n", hi, lo);
    if (hi != 2 || lo != 0x14 || sensor_write(i2c, 0x100, 0)) goto done;
    delay_ms(20);
    for (unsigned i = 0; sensor_init_data[i].reg != SEQUENCE_END; i++) {
        unsigned reg = sensor_init_data[i].reg, val = sensor_init_data[i].val;
        if (quitting || getppid() != parent) goto done;
        if (reg == SEQUENCE_WAIT_MS) { delay_ms(val); continue; }
        if (reg == 0x100) continue; /* Start only after owned DMA is configured. */
        if (sensor_write(i2c, reg, val)) { fprintf(stderr, "register 0x%04x failed\n", reg); goto done; }
    }
    gamma[0] = 3; /* Reviewed Digilent scalar gamma IP, not legacy LUT registers. */
    if (set_focus(i2c, focus)) goto done;
    printf("FOCUS_POSITION %u (manual)\n", focus);
    if (sensor_read(i2c, 0x34c, &wh) || sensor_read(i2c, 0x34d, &wl) ||
        sensor_read(i2c, 0x34e, &hh) || sensor_read(i2c, 0x34f, &hl)) goto done;
    printf("SENSOR_DIMENSIONS %ux%u\n", (wh << 8) | wl, (hh << 8) | hl);
    if (((wh << 8) | wl) != 1920 || ((hh << 8) | hl) != 1080) goto done;
    if (ioctl(camera, AH_CAM_START)) { perror("start DMA"); goto done; }
    started = 1;
    if (sensor_write(i2c, 0x100, 1)) goto done;
    delay_ms(500);
    uint8_t stream, count1, count2;
    if (sensor_read(i2c, 0x100, &stream) || sensor_read(i2c, 5, &count1)) goto done;
    delay_ms(100);
    if (sensor_read(i2c, 5, &count2)) goto done;
    printf("SENSOR_STREAM %u COUNTER %u -> %u\n", stream, count1, count2);
    /* The supplied CSI RTL holds FIFO reset for 200M byte-clock cycles,
     * then gates writes for another 100M. Wait for actual frames, not a
     * guessed 500ms delay; the initial byte clock exists only while streaming. */
    double warmup_at = now();
    unsigned warmup_index = 0, warmup_changes = 0;
    while (!quitting && getppid() == parent && now() - warmup_at < 30) {
        if (ioctl(camera, AH_CAM_STATUS, &status)) goto done;
        if (status.write_index >= 3 || status.status & 1) goto done;
        if (status.status & 0xff0) {
            printf("WARMUP_DMA_STATUS 0x%08x\n", status.status);
            if (ioctl(camera, AH_CAM_CLEAR)) goto done;
        }
        if (status.write_index != warmup_index) {
            warmup_index = status.write_index; warmup_changes++;
            if (warmup_changes >= 4) break;
        }
        delay_ms(10);
    }
    printf("WARMUP seconds=%.3f transitions=%u\n", now() - warmup_at, warmup_changes);
    if (quitting || getppid() != parent || warmup_changes < 4) { fprintf(stderr, "CSI_STARTUP_TIMEOUT\n"); goto done; }
    if (ioctl(camera, AH_CAM_CLEAR) || ioctl(camera, AH_CAM_STATUS, &status)) goto done;
    unsigned previous = status.write_index;
    double begin = now(), changed_at = begin, report_at = begin, preview_at = begin, published_at = begin;
    printf("CAPTURE_STARTED seconds=%u\n", seconds);
    while (!quitting && getppid() == parent && now() - begin < seconds) {
        if (ioctl(camera, AH_CAM_STATUS, &status)) goto done;
        if (status.status & 0xff0 || status.write_index >= 3 || status.status & 1) {
            fprintf(stderr, "DMA_FAILURE status=0x%08x index=%u\n", status.status, status.write_index); goto done;
        }
        seen |= 1U << status.write_index;
        int frame_changed = status.write_index != previous;
        if (frame_changed) { changes++; changed_at = now(); previous = status.write_index; }
        if (now() - changed_at > 2) { fprintf(stderr, "FRAME_STALLED\n"); goto done; }
        /* Begin just after a store transition, giving a complete two-store
         * window for the copy. Unsynchronized polling wastes safe frames. */
        if (argc == 5 && frame_changed && now() - preview_at >= 1.0 / 30.0) {
            preview_at = now();
            unsigned old_sequence = preview_sequence;
            if (camera_preview(argv[4], camera, frames, &info, &preview_sequence)) {
                fprintf(stderr, "PREVIEW_PUBLISH_FAILED\n"); goto done;
            }
            if (preview_sequence != old_sequence) published_at = now();
            if (now() - published_at > 5) { fprintf(stderr, "PREVIEW_STALLED\n"); goto done; }
        }
        if (now() - report_at >= 1) {
            unsigned nonzero, done_index = (status.write_index + 2) % 3;
            uint32_t hash = sample_hash(frames + done_index * info.buffer_stride, info.frame_bytes, &nonzero);
            printf("{\"seconds\":%.3f,\"observed_transitions\":%u,\"interval_transitions\":%u,\"write_index\":%u,\"seen_mask\":%u,\"status\":%u,\"sample_hash\":%u,\"nonzero_samples\":%u}\n",
                   now() - begin, changes, changes - last_changes, status.write_index, seen, status.status, hash, nonzero);
            if (!nonzero) {
                for (unsigned b = 0; b < 3; b++) {
                    unsigned nz; uint32_t bh = sample_hash(frames + b * info.buffer_stride, info.frame_bytes, &nz);
                    fprintf(stderr, "BUFFER%u hash=%u nonzero=%u\n", b, bh, nz);
                }
                fprintf(stderr, "EMPTY_FRAME\n"); goto done;
            }
            last_changes = changes;
            report_at = now();
        }
        delay_ms(1);
    }
    if (quitting || getppid() != parent) { fprintf(stderr, "CAPTURE_INTERRUPTED\n"); goto done; }
    if (changes < seconds * 5 || seen != 7) { fprintf(stderr, "INSUFFICIENT_FRAME_TRANSITIONS\n"); goto done; }
    valid = 1;
done:
    if (i2c >= 0 && sensor_write(i2c, 0x100, 0)) { fprintf(stderr, "STREAM_OFF_FAILED\n"); valid = 0; }
    if (camera >= 0) {
        if (ioctl(camera, AH_CAM_STOP)) { perror("stop DMA"); valid = 0; }
        else {
            printf("DMA_HALTED\n");
            if (started && valid && !ioctl(camera, AH_CAM_STATUS, &status) && status.write_index < 3) {
                unsigned done_index = (status.write_index + 2) % 3, nonzero;
                const uint8_t *frame = frames + done_index * info.buffer_stride;
                sample_hash(frame, info.frame_bytes, &nonzero);
                if (nonzero && !write_frame(argv[2], frame, info.frame_bytes)) {
                    printf("CAPTURE_COMPLETE transitions=%u seen_mask=%u bytes=%u saved=%s\n", changes, seen, info.frame_bytes, argv[2]); ret = 0;
                }
            }
        }
    }
    camera_preview_shutdown();
    if (frames != MAP_FAILED) munmap(frames, info.map_bytes);
    if (gamma != MAP_FAILED) munmap((void *)gamma, 4096);
    if (gpio != MAP_FAILED) munmap((void *)gpio, 4096);
    if (mem >= 0) close(mem);
    if (i2c >= 0) close(i2c);
    if (camera >= 0) close(camera);
    return ret;
}
