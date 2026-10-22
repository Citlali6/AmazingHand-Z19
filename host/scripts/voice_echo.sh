#!/bin/sh
# Independent PS audio verification; no FPGA or robot commands.
set -eu
voice_host_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$voice_host_dir"
exec "${VOICE_PYTHON:-python3}" -u -m app.voice.echo "$@"
