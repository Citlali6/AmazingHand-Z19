#!/bin/sh
# Reuse the already-installed, board-targeted small-model voice environment.
set -eu
[ "$#" -ge 2 ] || { echo 'usage: voice_color.sh VOICE_ASSETS_ROOT PREVIEW_DIRECTORY [voice options]' >&2; exit 2; }
voice_assets=$(CDPATH= cd -- "$1" && pwd)
voice_directory=$2
shift 2
voice_scripts=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
voice_native="$voice_assets/native"
[ -x "$voice_assets/.venv/bin/python" ] && [ -x "$voice_native/usr/bin/arecord" ] || { echo 'Missing verified board voice runtime' >&2; exit 2; }
export PATH="$voice_native/usr/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LD_LIBRARY_PATH="$voice_native/lib/aarch64-linux-gnu:$voice_native/usr/lib/aarch64-linux-gnu:$voice_native/usr/lib/aarch64-linux-gnu/pulseaudio${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export ALSA_CONFIG_PATH="$voice_native/usr/share/alsa/alsa.conf"
export ALSA_CONFIG_DIR="$voice_native/usr/share/alsa"
export PYTHONPATH="$voice_assets/host"
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
exec "$voice_assets/.venv/bin/python" -u "$voice_scripts/voice_color.py" \
  --directory "$voice_directory" --model "$voice_assets/host/models/vosk-model-small-cn-0.22" "$@"
