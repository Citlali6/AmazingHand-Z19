"""Build a local-only offline Z19 verification ZIP without passwords/recordings.

Requires the existing voice foundation ZIP, verified native/Piper assets and
the three Python3.7 extra wheels. Refuses to overwrite output. Not a release.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import zipfile


def checked(path, expected):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected:
        raise ValueError('SHA256 mismatch: ' + str(path))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('output', type=Path)
    p.add_argument('--native', required=True, type=Path)
    p.add_argument('--piper', required=True, type=Path)
    p.add_argument('--extra-wheels', required=True, type=Path)
    args = p.parse_args()
    repo = Path(__file__).resolve().parents[1]
    foundation = repo / 'deliverables/voice_usb/voice_usb_package_20261018_v2.zip'
    checked(foundation, '52563065abd783a212d3ebfd91bb0d8cf1f44a24d7e70cf33ba088e4508a4ae6')
    native = json.loads((repo / 'docs/voice/echo_native_assets_20261022.json').read_text())
    checked(args.native / 'native-payload.tar.gz', native['payload_sha256'])
    tts = json.loads((repo / 'docs/voice/echo_tts_assets_20261022.json').read_text())
    for item in tts['files']:
        checked(args.piper / item['file'], item['sha256'])
    lock = (repo / 'host/requirements-voice-echo.lock').read_text()
    wheels = []
    for name in ('importlib_metadata', 'typing_extensions', 'zipp'):
        found = list(args.extra_wheels.glob(name + '-*.whl'))
        if len(found) != 1:
            raise ValueError('Expected one extra wheel: ' + name)
        wheel = found[0]
        package, version = wheel.name.split('-')[:2]
        match = re.search(r'^' + re.escape(package + '==' + version) + r' --hash=sha256:([a-f0-9]{64})$', lock, re.M)
        if not match:
            raise ValueError('Extra wheel is not in lock: ' + wheel.name)
        checked(wheel, match[1])
        wheels.append(wheel)
    # A ZIP stores symlinks as ordinary files; keep native Linux libraries in
    # their original tar archives so target permissions/links remain intact.
    with zipfile.ZipFile(args.output, 'x', compression=zipfile.ZIP_STORED) as output:
        with zipfile.ZipFile(foundation) as source:
            for item in source.infolist():
                if item.is_dir():
                    continue
                parts = PurePosixPath(item.filename).parts
                if not parts or '..' in parts or PurePosixPath(item.filename).is_absolute():
                    raise ValueError('Unsafe foundation path')
                name = str(PurePosixPath(*parts[1:]))
                if name == 'host/app/voice/echo.py':
                    continue
                output.writestr(name, source.read(item))
        for name in ['host/app/voice/echo.py', 'host/scripts/voice_echo.sh',
                     'host/scripts/voice_echo_install.sh', 'host/scripts/voice_echo_standalone.sh',
                     'host/requirements-voice-echo.lock']:
            output.write(repo / name, name)
        for wheel in wheels:
            output.write(wheel, 'wheels/' + wheel.name)
        output.write(args.native / 'native-payload.tar.gz', 'native-payload.tar.gz')
        output.write(repo / 'docs/voice/echo_native_assets_20261022.json', 'native-manifest.json')
        for item in tts['files']:
            output.write(args.piper / item['file'], 'neural-tts/' + item['file'])
        output.write(repo / 'docs/voice/echo_tts_assets_20261022.json', 'neural-tts/manifest.json')
        output.writestr('LOCAL_ONLY.txt', 'Local verification bundle. Model dataset license Unknown. Do not republish model weights.\n')
    print(json.dumps(dict(file=str(args.output), bytes=args.output.stat().st_size,
                          sha256=hashlib.sha256(args.output.read_bytes()).hexdigest())))


if __name__ == '__main__':
    main()
