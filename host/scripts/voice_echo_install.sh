#!/bin/sh
# Run inside a freshly extracted LOCAL verification bundle on Linux ARM64.
# Installs only under that bundle; no system package manager or FPGA operations.
set -eu
voice_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$voice_root"
[ "$(uname -m)" = aarch64 ] || { echo 'Requires Linux aarch64' >&2; exit 1; }
[ ! -e .venv ] && [ ! -e native ] && [ ! -e neural-tts/piper ] || {
    echo 'Use a new deployment directory; existing environment/native files preserved.' >&2; exit 1;
}
python3 - <<'PY'
from pathlib import Path
import hashlib, json, tarfile, posixpath
root = Path.cwd()
native = json.loads((root / 'native-manifest.json').read_text())
tts = json.loads((root / 'neural-tts/manifest.json').read_text())
def check(path, expected):
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise SystemExit('Asset SHA256 mismatch: ' + str(path))
check(root / 'native-payload.tar.gz', native['payload_sha256'])
for item in tts['files']:
    check(root / 'neural-tts' / item['file'], item['sha256'])
for filename, destination in [('native-payload.tar.gz', 'native'),
                               ('neural-tts/piper_linux_aarch64.tar.gz', 'neural-tts')]:
    with tarfile.open(filename) as source:
        members = source.getmembers()
        for member in members:
            name = posixpath.normpath(member.name)
            if name.startswith('/') or name == '..' or name.startswith('../'):
                raise SystemExit('Unsafe archive member')
            if member.issym() or member.islnk():
                link = posixpath.normpath(posixpath.join(posixpath.dirname(name), member.linkname))
                if member.linkname.startswith('/') or link == '..' or link.startswith('../'):
                    raise SystemExit('Unsafe archive link')
        source.extractall(destination, members=members)
PY
python3 -m venv --without-pip .venv
PYTHONPATH="$voice_root/wheels/pip-24.0-py3-none-any.whl" \
    .venv/bin/python -m pip install --no-index --find-links wheels \
    --require-hashes -r host/requirements-voice-echo.lock
.venv/bin/python -m pip check
sh host/scripts/voice_echo_standalone.sh --check
