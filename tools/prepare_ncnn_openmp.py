"""Prepare a private GCC 9.2 Linux/AArch64 OpenMP header, never install to /usr.

Inputs: unmodified official GCC 9.2 omp.h.in; output must be a new directory.
Linux ABI: libgomp/config/linux/omp-lock.h, 4-byte int + 64-bit pointer.
Retains GCC license and GCC Runtime Library Exception notices in the header.
"""
import argparse
import hashlib
from pathlib import Path

PROBE = r'''#include <omp.h>
#include <cstdio>
struct LinuxNestedLock { int lock,count; void* owner; };
static_assert(sizeof(int)==4 && sizeof(void*)==8, "Linux AArch64 profile");
static_assert(sizeof(omp_lock_t)==sizeof(int), "lock ABI");
static_assert(alignof(omp_lock_t)==alignof(int), "lock alignment");
static_assert(sizeof(omp_nest_lock_t)==sizeof(LinuxNestedLock), "nested lock ABI");
static_assert(alignof(omp_nest_lock_t)==alignof(LinuxNestedLock), "nested lock alignment");
int main(){int count=0;
#pragma omp parallel num_threads(4) reduction(+:count)
{count+=1;}
printf("OPENMP_THREADS=%d\n",count);return count==4?0:1;}
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('template',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    if args.output.exists(): parser.error('output must be new')
    expected='c76a386994d6ff3c0a3c544538237d8e12a2109cce3d84937d539718f6809417'
    if hashlib.sha256(args.template.read_bytes()).hexdigest()!=expected:
        parser.error('GCC 9.2 official template SHA256 mismatch')
    text=args.template.read_text()
    for key,value in {'OMP_LOCK_SIZE':4,'OMP_LOCK_ALIGN':4,
                      'OMP_NEST_LOCK_SIZE':16,'OMP_NEST_LOCK_ALIGN':8}.items():
        text=text.replace('@'+key+'@',str(value))
    if '@OMP_' in text: parser.error('unknown GCC template placeholders')
    args.output.mkdir(parents=True)
    (args.output/'omp.h').write_text(text)
    (args.output/'probe.cpp').write_text(PROBE)
    print('GCC_TEMPLATE_SHA256',hashlib.sha256(args.template.read_bytes()).hexdigest())


if __name__=='__main__': main()
