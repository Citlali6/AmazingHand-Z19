"""Fetch fixed ARM64 Piper/Chinese assets for local board verification.

Model weights are not committed or republished: upstream MODEL_CARD reports
dataset license Unknown. Preserve that attribution and review before distribution.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('output', type=Path)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    manifest_path = Path(__file__).resolve().parents[1] / 'docs/voice/echo_tts_assets_20261022.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    def one(item):
        request = urllib.request.Request(item['url'], headers={'User-Agent': 'VisionGrasp local voice verification'})
        data = urllib.request.urlopen(request, timeout=180).read()
        if len(data) != item['size'] or hashlib.sha256(data).hexdigest() != item['sha256']:
            raise ValueError('Asset differs from fixed SHA256: ' + item['file'])
        (args.output / item['file']).write_bytes(data)
        return item['file']
    with ThreadPoolExecutor(max_workers=3) as pool:
        names = list(pool.map(one, manifest['files']))
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps(dict(verified=names, distribution='local verification only')))


if __name__ == '__main__':
    main()
