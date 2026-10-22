#!/bin/sh
# LOCAL verification bundle entry, valid after voice_echo_install.sh succeeds.
set -eu
voice_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
voice_native="$voice_root/native"
export PATH="$voice_native/usr/bin:$PATH"
export LD_LIBRARY_PATH="$voice_native/lib/aarch64-linux-gnu:$voice_native/usr/lib/aarch64-linux-gnu:$voice_native/usr/lib/aarch64-linux-gnu/pulseaudio${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export ALSA_CONFIG_PATH="$voice_native/usr/share/alsa/alsa.conf"
export ALSA_CONFIG_DIR="$voice_native/usr/share/alsa"
export PYTHONPATH="$voice_root/host"
cd "$voice_root/host"
exec "$voice_root/.venv/bin/python" -u -m app.voice.echo \
    --tts-engine piper --tts-executable "$voice_root/neural-tts/piper/piper" \
    --tts-model "$voice_root/neural-tts/zh_CN-huayan-medium.onnx" "$@"
