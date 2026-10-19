"""Download the official Chinese model into a NEW assets directory, not Git.

Records a local SHA256 for reproducibility. It is not a publisher-signed digest.
Does not install packages or execute model files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import stat
import urllib.request
import zipfile
from pathlib import Path

NAME = 'vosk-model-small-cn-0.22'
URL = 'https://alphacephei.com/vosk/models/' + NAME + '.zip'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='New directory; must not exist')
    args = parser.parse_args()
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    archive = root / (NAME + '.zip')
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(URL, timeout=30) as response, archive.open('xb') as out:
        if not response.geturl().startswith('https://alphacephei.com/'):
            raise RuntimeError('Unexpected model download redirect')
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            if size > 100 * 1024 * 1024:
                raise RuntimeError('Model archive unexpectedly large')
            digest.update(chunk)
            out.write(chunk)
            if size % (10 * 1024 * 1024) == 0:
                print('Downloaded %d MiB' % (size // (1024 * 1024)), flush=True)
    with zipfile.ZipFile(archive) as source:
        if sum(item.file_size for item in source.infolist()) > 500 * 1024 * 1024:
            raise RuntimeError('Uncompressed model unexpectedly large')
        names = set()
        for item in source.infolist():
            parts = Path(item.filename).parts
            target = (root / item.filename).resolve()
            if (not parts or parts[0] != NAME or target == root
                    or root not in target.parents or item.filename in names
                    or '\\' in item.filename
                    or stat.S_ISLNK(item.external_attr >> 16)):
                raise RuntimeError('Unsafe or duplicate archive member: ' + item.filename)
            names.add(item.filename)
        for item in source.infolist():
            target = root / item.filename
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with source.open(item) as inp, target.open('xb') as out:
                    shutil.copyfileobj(inp, out)
    model = root / NAME
    if not all((model / name).is_file() for name in ('am/final.mdl', 'conf/mfcc.conf')):
        raise RuntimeError('Required model files missing')
    with (root / 'model_provenance.json').open('x', encoding='utf-8') as out:
        json.dump(dict(source=URL, archive=archive.name, bytes=size,
                       sha256=digest.hexdigest(), model=NAME,
                       publisher_digest_verified=False, board_validation='pending'), out, indent=2)
    print('MODEL_DOWNLOADED: ' + str(model))


if __name__ == '__main__':
    main()
