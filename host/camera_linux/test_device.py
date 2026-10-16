"""Hardware bench checks for the reviewed driver. Run only on the Z19.

busy: verify exclusive ownership during an existing capture.
idle: verify ABI, rejected mappings, VMA/module lifetime and stopped DMA.
"""
import argparse
import errno
import fcntl
import mmap
import os
import struct
import subprocess

DEVICE = '/dev/ah_camera0'
INFO = 0x80384101
STATUS = 0x80104104


def expect_busy():
    try:
        fd = os.open(DEVICE, os.O_RDONLY)
    except OSError as error:
        assert error.errno == errno.EBUSY, error
        return
    os.close(fd)
    raise AssertionError('second open was accepted')


def rejected_map(fd, length, prot, flags, offset=0):
    try:
        mapped = mmap.mmap(fd, length, flags=flags, prot=prot, offset=offset)
    except OSError as error:
        assert error.errno in (errno.EINVAL, errno.EACCES), error
        return
    mapped.close()
    raise AssertionError('invalid mapping was accepted')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['busy', 'idle'])
    args = parser.parse_args()
    if args.mode == 'busy':
        expect_busy()
        print('EXCLUSIVE_OPEN_PASS')
        return
    fd = os.open(DEVICE, os.O_RDWR)
    mapped = None
    try:
        info = bytearray(56)
        fcntl.ioctl(fd, INFO, info)
        a, b, c, frame, stride, total, width, height, count, version, reserved = struct.unpack('<3Q8I', info)
        assert (frame, width, height, count, version, reserved) == (6220800, 1920, 1080, 3, 1, 0)
        assert stride % 4096 == 0 and stride >= frame and total == stride * 3
        assert [b - a, c - b] == [stride, stride]
        assert 0 < a < c + stride < 2**32
        status = bytearray(16)
        fcntl.ioctl(fd, STATUS, status)
        control, flags, index, hw_version = struct.unpack('<4I', status)
        assert flags & 1 and not control & 1 and hw_version == 0x62000050
        try:
            fcntl.ioctl(fd, 0xdeadbeef, 0)
        except OSError as error:
            assert error.errno == errno.ENOTTY
        else:
            raise AssertionError('unknown ioctl accepted')
        rejected_map(fd, total, mmap.PROT_READ | mmap.PROT_WRITE, mmap.MAP_SHARED)
        rejected_map(fd, 4096, mmap.PROT_READ, mmap.MAP_SHARED)
        rejected_map(fd, total, mmap.PROT_READ, mmap.MAP_SHARED, 4096)
        rejected_map(fd, total, mmap.PROT_READ, mmap.MAP_PRIVATE)
        expect_busy()
        mapped = mmap.mmap(fd, total, flags=mmap.MAP_SHARED, prot=mmap.PROT_READ)
        os.close(fd)
        fd = -1
        expect_busy()  # Mapping keeps the file and module alive after fd close.
        attempt = subprocess.run(['rmmod', 'ah_camera0'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        assert attempt.returncode != 0 and os.path.isdir('/sys/module/ah_camera0')
        mapped.close()
        mapped = None
        fd = os.open(DEVICE, os.O_RDONLY)
        fcntl.ioctl(fd, STATUS, status)
        assert struct.unpack('<4I', status)[1] & 1
        print('ABI_MAPPING_LIFETIME_HALT_PASS')
    finally:
        if mapped is not None:
            mapped.close()
        if fd >= 0:
            os.close(fd)


if __name__ == '__main__':
    main()
