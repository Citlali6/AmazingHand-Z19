/* Copy completed coherent DMA stores into ordinary RAM before encoding.
 * Four disjoint copy slices reduce noncached-read latency. Two JPEG workers
 * overlap encoding with capture; busy/unsafe/obsolete frames are discarded.
 * JPEG workers never access DMA, MMIO or I2C. No DMA cache attributes change.
 */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <setjmp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>
#include <jpeglib.h>
#include "camera_preview.h"

#define WIDTH 1920U
#define HEIGHT 1080U
#define BYTES (WIDTH * HEIGHT * 3U)
#define WORKERS 2U

struct jpeg_errors { struct jpeg_error_mgr base; jmp_buf jump; };
struct job {
    pthread_t thread;
    uint8_t *pixels, *jpeg;
    unsigned long jpeg_bytes;
    unsigned capture;
    double stamp, copy_ms;
    int state; /* 0 free, 1 copying, 2 ready, 3 encoding */
    struct jpeg_compress_struct codec;
    struct jpeg_errors errors;
};
static struct job jobs[WORKERS];
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t ready = PTHREAD_COND_INITIALIZER;
static unsigned created, published, capture_sequence, last_capture;
static unsigned busy_skips, copy_discards, obsolete_discards;
static int stopping, failed;
static char directory[4096];

static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}
static void jpeg_error(j_common_ptr codec) {
    struct jpeg_errors *errors = (struct jpeg_errors *)codec->err;
    (*codec->err->output_message)(codec);
    longjmp(errors->jump, 1);
}
static int encode(struct job *job) {
    memset(&job->codec, 0, sizeof(job->codec));
    job->jpeg = NULL;
    job->jpeg_bytes = 0;
    job->codec.err = jpeg_std_error(&job->errors.base);
    job->errors.base.error_exit = jpeg_error;
    if (setjmp(job->errors.jump)) {
        jpeg_destroy_compress(&job->codec);
        free(job->jpeg);
        job->jpeg = NULL;
        return -1;
    }
    jpeg_create_compress(&job->codec);
    jpeg_mem_dest(&job->codec, &job->jpeg, &job->jpeg_bytes);
    job->codec.image_width = WIDTH;
    job->codec.image_height = HEIGHT;
    job->codec.input_components = 3;
    job->codec.in_color_space = JCS_EXT_BGR;
    jpeg_set_defaults(&job->codec);
    jpeg_set_quality(&job->codec, 85, TRUE);
    job->codec.dct_method = JDCT_FASTEST;
    jpeg_start_compress(&job->codec, TRUE);
    while (job->codec.next_scanline < HEIGHT) {
        JSAMPROW row = job->pixels + job->codec.next_scanline * WIDTH * 3;
        if (jpeg_write_scanlines(&job->codec, &row, 1) != 1) {
            jpeg_destroy_compress(&job->codec);
            free(job->jpeg);
            job->jpeg = NULL;
            return -1;
        }
    }
    jpeg_finish_compress(&job->codec);
    jpeg_destroy_compress(&job->codec);
    return 0;
}
/* Called with lock held: serialize metadata publication, never regress time. */
static int publish(struct job *job, double encode_ms) {
    char path[4096], meta[4096], temp[4096], name[64];
    unsigned next = published + 1;
    if (job->capture <= last_capture) { obsolete_discards++; return 0; }
    snprintf(name, sizeof(name), "preview-%08u.jpg", next);
    if (snprintf(path, sizeof(path), "%s/%s", directory, name) >= (int)sizeof(path) ||
        snprintf(meta, sizeof(meta), "%s/metadata.json", directory) >= (int)sizeof(meta) ||
        snprintf(temp, sizeof(temp), "%s/metadata.json.next", directory) >= (int)sizeof(temp)) return -1;
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0) return -1;
    size_t written = 0;
    while (written < job->jpeg_bytes) {
        ssize_t result = write(fd, job->jpeg + written, job->jpeg_bytes - written);
        if (result < 0 && errno == EINTR) continue;
        if (result <= 0) { close(fd); return -1; }
        written += result;
    }
    if (close(fd)) return -1;
    FILE *output = fopen(temp, "wx");
    if (!output) return -1;
    int error = fprintf(output,
        "{\"sequence\":%u,\"capture_sequence\":%u,\"file\":\"%s\",\"monotonic\":%.6f,"
        "\"published_monotonic\":%.6f,\"capture_width\":1920,\"capture_height\":1080,"
        "\"preview_width\":1920,\"preview_height\":1080,\"copy_ms\":%.3f,\"encode_ms\":%.3f,"
        "\"copy_discards\":%u,\"busy_skips\":%u,\"obsolete_discards\":%u}\n",
        next, job->capture, name, job->stamp, now(), job->copy_ms, encode_ms,
        copy_discards, busy_skips, obsolete_discards) < 0;
    if (fclose(output)) error = 1;
    if (error || rename(temp, meta)) return -1;
    published = next;
    last_capture = job->capture;
    if (next > 8) {
        if (snprintf(path, sizeof(path), "%s/preview-%08u.jpg", directory, next - 8) >= (int)sizeof(path)) return -1;
        if (unlink(path)) return -1;
    }
    return 0;
}
static void *encoder(void *arg) {
    struct job *job = arg;
    for (;;) {
        pthread_mutex_lock(&lock);
        while (!stopping && job->state != 2) pthread_cond_wait(&ready, &lock);
        if (stopping) { pthread_mutex_unlock(&lock); break; }
        job->state = 3;
        pthread_mutex_unlock(&lock);
        double begin = now();
        int error = encode(job);
        double encode_ms = (now() - begin) * 1000;
        pthread_mutex_lock(&lock);
        if (error || (!stopping && publish(job, encode_ms))) failed = 1;
        free(job->jpeg);
        job->jpeg = NULL;
        job->state = 0;
        pthread_mutex_unlock(&lock);
    }
    return NULL;
}
struct slice { uint8_t *dst; const uint8_t *src; size_t bytes; };
static void *copy_slice(void *arg) {
    const struct slice *slice = arg;
    memcpy(slice->dst, slice->src, slice->bytes);
    return NULL;
}
static int initialize(const char *dir) {
    if (snprintf(directory, sizeof(directory), "%s", dir) >= (int)sizeof(directory)) return -1;
    for (unsigned i = 0; i < WORKERS; i++) {
        if (posix_memalign((void **)&jobs[i].pixels, 64, BYTES)) return -1;
        if (pthread_create(&jobs[i].thread, NULL, encoder, &jobs[i])) return -1;
        created++;
    }
    return 0;
}
int camera_preview(const char *dir, int fd, const uint8_t *frames,
                   const struct ah_camera0_info *info, unsigned *sequence) {
    struct ah_camera0_status before, after;
    if (!created && initialize(dir)) return -1;
    pthread_mutex_lock(&lock);
    *sequence = published;
    if (failed) { pthread_mutex_unlock(&lock); return -1; }
    struct job *job = NULL;
    for (unsigned i = 0; i < WORKERS; i++) if (!jobs[i].state) { job = &jobs[i]; break; }
    if (!job) { busy_skips++; pthread_mutex_unlock(&lock); return 0; }
    job->state = 1;
    pthread_mutex_unlock(&lock);
    double begin = now();
    if (ioctl(fd, AH_CAM_STATUS, &before) || before.write_index >= 3 || before.status & 0xff1) return -1;
    unsigned done = (before.write_index + 2) % 3;
    const uint8_t *source = frames + done * info->buffer_stride;
    pthread_t threads[4];
    struct slice slices[4];
    unsigned started = 0;
    __sync_synchronize();
    for (unsigned i = 0; i < 4; i++) {
        slices[i] = (struct slice){job->pixels + i * (BYTES / 4), source + i * (BYTES / 4), BYTES / 4};
        if (pthread_create(&threads[i], NULL, copy_slice, &slices[i])) break;
        started++;
    }
    for (unsigned i = 0; i < started; i++) pthread_join(threads[i], NULL);
    __sync_synchronize();
    if (started != 4 || ioctl(fd, AH_CAM_STATUS, &after)) return -1;
    /* Include both status queries in the bound, so a delayed final ioctl
     * cannot hide a complete write and wrap of the selected store. */
    job->copy_ms = (now() - begin) * 1000;
    pthread_mutex_lock(&lock);
    /* This fixed sensor profile runs at ~55.6 Hz (18 ms/store). A complete
     * overwrite-and-wrap of the previous completed store needs at least two
     * periods (~36 ms). Bound the entire status/copy/status window to 30 ms
     * and reject if that store became writable. Do not reuse for faster modes. */
    if (job->copy_ms > 30 || after.write_index == done || after.status & 0xff1) {
        copy_discards++;
        job->state = 0;
    } else {
        job->capture = ++capture_sequence;
        job->stamp = now();
        job->state = 2;
        pthread_cond_broadcast(&ready);
    }
    *sequence = published;
    pthread_mutex_unlock(&lock);
    return 0;
}
void camera_preview_shutdown(void) {
    pthread_mutex_lock(&lock);
    stopping = 1;
    pthread_cond_broadcast(&ready);
    pthread_mutex_unlock(&lock);
    for (unsigned i = 0; i < created; i++) pthread_join(jobs[i].thread, NULL);
    for (unsigned i = 0; i < WORKERS; i++) free(jobs[i].pixels);
    printf("PREVIEW_HD published=%u copy_discards=%u busy_skips=%u obsolete_discards=%u\n",
           published, copy_discards, busy_skips, obsolete_discards);
}
