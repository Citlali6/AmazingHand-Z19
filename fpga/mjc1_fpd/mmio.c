/* Native AArch64 MMIO: full 32-bit accesses with explicit device barriers. */
#include <stdint.h>
#include <stdlib.h>
#ifndef __aarch64__
#error "Build this file on the AArch64 Z19 board"
#endif

uint32_t mjc_read32(void *base, uint32_t offset) {
    if ((offset & 3) || offset > 4092) abort();
    __asm__ volatile("dmb sy" ::: "memory");
    uint32_t result = *(volatile uint32_t *)((char *)base + offset);
    __asm__ volatile("dsb sy" ::: "memory");
    return result;
}

void mjc_write32(void *base, uint32_t offset, uint32_t value) {
    if ((offset & 3) || offset > 4092) abort();
    __asm__ volatile("dmb sy" ::: "memory");
    *(volatile uint32_t *)((char *)base + offset) = value;
    __asm__ volatile("dsb sy" ::: "memory");
}

#ifdef MJC_MMIO_MAIN
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
int main(int argc, char **argv) {
    setbuf(stdout, NULL);
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {perror("open"); return 2;}
    void *base = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0xa0000000UL);
    if (base == MAP_FAILED) {perror("mmap"); return 2;}
    puts("STEP READ_ID");
    uint32_t id = mjc_read32(base, 0), version = mjc_read32(base, 4);
    printf("ID=%08x VERSION=%08x\n", id, version);
    if (id != 0x31434a4d || version != 0x10001) return 3;
    if (argc == 2 && strcmp(argv[1], "--rwtest") == 0) {
        puts("STEP TARGET_WRITE_32");
        mjc_write32(base, 8, 0);
        for (unsigned i=0;i<8;i++) mjc_write32(base, 0x10+i*4, 950);
        for (unsigned i=0;i<8;i++) if (mjc_read32(base, 0x50+i*4)!=950) return 4;
        puts("STEP FEEDBACK_STAGE_32");
        for (unsigned i=0;i<8;i++) mjc_write32(base, 0x80+i*4, 950);
        for (unsigned i=0;i<8;i++) if (mjc_read32(base, 0x80+i*4)!=950) return 5;
        puts("STEP FEEDBACK_COMMIT_32");
        mjc_write32(base, 0xa0, 1);
        if (mjc_read32(base, 0x44)!=1) return 6;
        puts("NATIVE32_MMIO_PASS");
    }
    munmap(base,4096); close(fd);
    return 0;
}
#endif
