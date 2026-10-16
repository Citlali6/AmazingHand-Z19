"""PC receive test for real MJPEG resolution, freshness and delivery rate.

Uses Pillow on the PC to decode every JPEG. Evidence and the first frame are
created exclusively. This measures received frames, not browser rendering FPS.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import time
import urllib.request
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', default='http://127.0.0.1:8766')
    parser.add_argument('--seconds', type=int, default=30)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--snapshot', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists() or args.snapshot.exists():
        raise RuntimeError('evidence destination already exists')
    if not 1 <= args.seconds <= 600:
        raise ValueError('duration must be 1..600 seconds')
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    base = args.url.rstrip('/')
    for _ in range(90):
        with opener.open(base + '/status.json', timeout=5) as response:
            status = json.load(response)
        if status['state'] == 'LIVE':
            break
        if status['state'] == 'ERROR':
            raise AssertionError(status)
        time.sleep(.5)
    else:
        raise AssertionError('stream did not become live')
    records = []
    with opener.open(base + '/stream.mjpg', timeout=6) as response:
        assert response.headers.get_content_type() == 'multipart/x-mixed-replace'
        begin = time.perf_counter()
        while time.perf_counter() - begin < args.seconds:
            assert response.readline().strip() == b'--frame'
            headers = {}
            while True:
                line = response.readline().strip()
                if not line:
                    break
                key, value = line.decode().split(':', 1)
                headers[key.lower()] = value.strip()
            size = int(headers['content-length'])
            assert 0 < size < 4000000
            jpeg = response.read(size)
            stamp = time.perf_counter()
            assert response.read(2) == b'\r\n'
            with Image.open(io.BytesIO(jpeg)) as image:
                image.load()
                assert image.size == (1920, 1080), image.size
            sequence = int(headers['x-sequence'])
            capture = float(headers['x-capture-monotonic'])
            if records:
                assert sequence > records[-1]['sequence']
                assert capture > records[-1]['capture']
            records.append({'time': stamp, 'sequence': sequence, 'capture': capture,
                            'bytes': size, 'hash': hashlib.sha256(jpeg).hexdigest()})
            if len(records) == 1:
                with args.snapshot.open('xb') as output:
                    output.write(jpeg)
    elapsed = records[-1]['time'] - records[0]['time']
    intervals = sorted(records[i]['time'] - records[i-1]['time'] for i in range(1, len(records)))
    assert elapsed > 0 and len(records) > 1
    with opener.open(base + '/status.json', timeout=5) as response:
        final_status = json.load(response)
    assert final_status['state'] == 'LIVE'
    result = {'url': base, 'preview_size': [1920,1080], 'frames': len(records),
              'elapsed_seconds': elapsed, 'received_fps': (len(records)-1)/elapsed,
              'published_fps': (records[-1]['sequence']-records[0]['sequence'])/(records[-1]['capture']-records[0]['capture']),
              'unique_jpegs': len({r['hash'] for r in records}),
              'missing_sequences': records[-1]['sequence']-records[0]['sequence']+1-len(records),
              'interval_p95_ms': intervals[int(len(intervals)*.95)]*1000,
              'max_interval_ms': max(intervals)*1000,
              'megabits_per_second': sum(r['bytes'] for r in records)*8/elapsed/1e6,
              'status_before': status, 'status_after': final_status,
              'every_jpeg_decoded_and_dimensions_checked': True,
              'sequences_and_capture_times_strictly_increasing': True}
    with args.output.open('x', encoding='utf-8') as output:
        json.dump(result, output, indent=2, ensure_ascii=False)
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
