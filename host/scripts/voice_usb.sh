#!/bin/sh
# Run from any directory; never installs packages or touches FPGA configuration.
set -eu
voice_host_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$voice_host_dir"
exec "${VOICE_PYTHON:-python3}" -m app.voice "$@"
