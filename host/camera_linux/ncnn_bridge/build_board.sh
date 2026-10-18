#!/bin/sh
# Use existing board compiler/OpenCV only. No install to /usr; no FPGA actions.
set -eu
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
[ "$(uname -m)" = aarch64 ] || { echo 'board AArch64 required' >&2; exit 1; }
[ "$#" = 2 ] || [ "$#" = 3 ] || { echo 'usage: build_board.sh NCNN_SOURCE NEW_BUILD_ROOT [PRIVATE_OMP_INCLUDE]' >&2; exit 1; }
source_dir=$(cd "$1" && pwd)
[ ! -e "$2" ] || { echo 'build root already exists; choose a NEW directory' >&2; exit 1; }
mkdir -p "$2"
build_root=$(cd "$2" && pwd)
bridge_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Restrict the build to this decoded YOLOv8 profile and NCNN internal helpers.
python3 - "$source_dir" "$build_root/layers.cmake" <<'PY'
from pathlib import Path
import re,sys
layers=set('Input MemoryData Convolution Swish Pooling Split Slice Concat Interp BinaryOp Reshape Permute Softmax Sigmoid Padding Packing Cast Crop ReLU Clip Mish HardSwish Scale Bias Flatten InnerProduct'.lower().split())
source=(Path(sys.argv[1])/'src/CMakeLists.txt').read_text()
lines=[]
for name in re.findall(r'ncnn_add_layer\((\w+)',source):
    lines.append('set(WITH_LAYER_%s %s CACHE BOOL "YOLOv8 CPU profile" FORCE)' %
                 (name.lower(),'ON' if name.lower() in layers else 'OFF'))
Path(sys.argv[2]).write_text('\n'.join(lines)+'\n')
PY
if [ "$#" = 3 ]; then
  omp_include=$(cd "$3" && pwd)
  [ -f "$omp_include/omp.h" ] && [ -f /usr/lib/libgomp.so.1 ] || { echo 'private OpenMP header/runtime missing' >&2; exit 1; }
  # Explicit versioned runtime avoids creating any /usr libgomp.so symlink.
  set -- "-DCMAKE_CXX_FLAGS=-I$omp_include" "-DCMAKE_C_FLAGS=-I$omp_include" \
    -DOpenMP_C_FLAGS=-fopenmp -DOpenMP_CXX_FLAGS=-fopenmp \
    -DOpenMP_C_LIB_NAMES=gomp -DOpenMP_CXX_LIB_NAMES=gomp \
    -DOpenMP_gomp_LIBRARY=/usr/lib/libgomp.so.1
else
  set --
fi
cmake -S "$source_dir" -B "$build_root/ncnn" \
  -C "$build_root/layers.cmake" "$@" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$build_root/local" \
  -DNCNN_VULKAN=OFF -DNCNN_SHARED_LIB=OFF -DNCNN_BUILD_TOOLS=OFF \
  -DNCNN_BUILD_EXAMPLES=OFF -DNCNN_BUILD_BENCHMARK=OFF -DNCNN_BUILD_TESTS=OFF \
  -DNCNN_INT8=OFF -DNCNN_ARM82=OFF -DNCNN_ARM82DOT=OFF \
  -DNCNN_ARM82FP16FML=OFF -DNCNN_ARM84BF16=OFF
cmake --build "$build_root/ncnn" --parallel 4
cmake --build "$build_root/ncnn" --target install
cmake -S "$bridge_source" -B "$build_root/bridge" \
  "$@" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$build_root/local"
cmake --build "$build_root/bridge" --parallel 4
sha256sum "$build_root/bridge/ah_ncnn_bridge"
