"""Prepare isolated ARM64 ALSA/eSpeak assets for PetaLinux glibc 2.30.

Downloads official Debian Buster packages; verifies package SHA256 from the
fixed index. No package is installed on the PC or board. Kept outside Git.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
import lzma
from pathlib import Path, PurePosixPath
import posixpath
import re
import tarfile
import urllib.request

BASE = 'https://archive.debian.org/debian/'
INDEX = 'dists/buster/main/binary-arm64/Packages.xz'
INDEX_SHA = '5384109c4b8ee015a5a913b150f7e07216af14eac5dc1d55e83deee2bb159b95'
ROOTS = {'alsa-utils', 'espeak-ng', 'espeak-ng-data', 'libespeak-ng1'}
# These existing board libraries are checked by ldd, never replaced here.
SYSTEM = {'libc6', 'libgcc1', 'libstdc++6', 'gcc-8-base'}


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={
        'User-Agent': 'VisionGrasp board audio compatibility'}), timeout=90).read()


def fields(data):
    index = {}
    for block in data.decode('utf-8').split('\n\n'):
        item, last = {}, None
        for line in block.splitlines():
            if line.startswith(' ') and last:
                item[last] += '\n' + line
            elif ': ' in line:
                last, value = line.split(': ', 1)
                item[last] = value
        if 'Package' in item:
            index[item['Package']] = item
    return index


def data_tar(deb):
    if deb[:8] != b'!<arch>\n':
        raise ValueError('Not a Debian ar archive')
    offset = 8
    while offset + 60 <= len(deb):
        header = deb[offset:offset + 60]
        size = int(header[48:58])
        name = header[:16].decode('ascii').strip().rstrip('/')
        offset += 60
        if name.startswith('data.tar'):
            return deb[offset:offset + size]
        offset += size + size % 2
    raise ValueError('Debian archive has no data member')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('output', type=Path)
    p.add_argument('--cache', type=Path, help='reuse prior downloads only after hash verification')
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    cached_index = args.cache / 'Packages.xz' if args.cache else None
    compressed = cached_index.read_bytes() if cached_index and cached_index.is_file() else fetch(BASE + INDEX)
    if hashlib.sha256(compressed).hexdigest() != INDEX_SHA:
        raise ValueError('Official package index differs from pinned snapshot')
    (args.output / 'Packages.xz').write_bytes(compressed)
    index = fields(lzma.decompress(compressed))
    wanted = set(ROOTS)
    while True:
        added = set()
        for name in wanted:
            deps = index[name].get('Depends', '') + ',' + index[name].get('Pre-Depends', '')
            for dep in deps.split(','):
                candidate = re.split(r'\s|\(', dep.strip())[0].split(':')[0]
                if candidate.startswith('lib') and candidate not in SYSTEM and candidate in index:
                    added.add(candidate)
        if added <= wanted:
            break
        wanted |= added
    packages = [index[name] for name in sorted(wanted)]
    def download(item):
        cached = args.cache / Path(item['Filename']).name if args.cache else None
        data = cached.read_bytes() if cached and cached.is_file() else fetch(BASE + item['Filename'])
        if len(data) != int(item['Size']) or hashlib.sha256(data).hexdigest() != item['SHA256']:
            raise ValueError('Package verification failed: ' + item['Package'])
        (args.output / Path(item['Filename']).name).write_bytes(data)
        return item, data
    with ThreadPoolExecutor(max_workers=4) as pool:
        downloaded = list(pool.map(download, packages))
    seen = set()
    payload = args.output / 'native-payload.tar.gz'
    with tarfile.open(payload, 'w:gz') as target:
        for item, raw in downloaded:
            with tarfile.open(fileobj=io.BytesIO(data_tar(raw)), mode='r:*') as source:
                for member in source:
                    name = posixpath.normpath(member.name)
                    if name == '.':
                        continue
                    # Service definitions/configuration are never deployed;
                    # their /dev/null masking links are outside our payload.
                    if name == 'etc' or name.startswith(('etc/', 'lib/systemd', 'usr/lib/systemd')):
                        continue
                    if name.startswith('../') or PurePosixPath(name).is_absolute():
                        raise ValueError('Unsafe package path')
                    if member.issym() or member.islnk():
                        link = posixpath.normpath(posixpath.join(posixpath.dirname(name), member.linkname))
                        if member.linkname.startswith('/') or link.startswith('../'):
                            raise ValueError('Unsafe package link: ' + name)
                    if name in seen:
                        continue
                    seen.add(name)
                    member.name = name
                    target.addfile(member, source.extractfile(member) if member.isfile() else None)
    manifest = dict(source=BASE, index=INDEX, index_sha256=INDEX_SHA,
                    target='aarch64 Linux glibc>=2.28 (tested board glibc2.30)',
                    installation='isolated extraction, no dpkg/apt or system library replacement',
                    packages=[{k: f.get(k) for k in ('Package', 'Version', 'Architecture', 'Filename', 'SHA256', 'Source')}
                              for f in packages],
                    payload_sha256=hashlib.sha256(payload.read_bytes()).hexdigest(),
                    licenses='Upstream copyright/license files retained under usr/share/doc; original source at Debian archive')
    (args.output / 'native-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps(dict(packages=len(packages), payload_bytes=payload.stat().st_size,
                          payload_sha256=manifest['payload_sha256'])))


if __name__ == '__main__':
    main()
