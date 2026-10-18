"""Bounded archival Z19 diagnosis; deliberately never labels old images LIVE.

Uses one unchanged JPEG and model manifest. No camera/PL/system operations.
"""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image',type=Path,required=True)
    parser.add_argument('--model-dir',type=Path,required=True)
    parser.add_argument('--bridge',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--conf',type=float,default=.35)
    parser.add_argument('--top-k',type=int,default=10)
    args=parser.parse_args()
    if platform.machine()!='aarch64':parser.error('run on the Z19 ARM64 board')
    if args.output.exists() or not 1<=args.top_k<=20 or not 0<args.conf<=1:
        parser.error('output must be new; top-k1..20, conf0..1')
    manifest=json.loads((args.model_dir/'manifest.json').read_text())
    hashes={name:hashlib.sha256((args.model_dir/name).read_bytes()).hexdigest()
            for name in ('model.ncnn.param','model.ncnn.bin')}
    if any(hashes[n]!=manifest['artifacts'][n]['sha256'] for n in hashes):
        raise ValueError('model manifest SHA mismatch')
    proc=subprocess.run([str(args.bridge.resolve()),str(args.model_dir.resolve()),str(manifest['input_size']),
                         '2',str(args.conf),'.45','1',str(args.top_k)],
                        input=json.dumps(str(args.image.resolve()))+'\n',text=True,
                        stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20,check=True)
    reply=json.loads(proc.stdout)
    if 'error' in reply:raise RuntimeError(reply)
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'host'))
    from app.vision.diagnostic import describe_native,named_rows
    value=dict(state='OFFLINE_DIAGNOSTIC',autonomous_grasp_allowed=False,
        architecture=platform.machine(),hostname=platform.node(),
        jpeg_sha256=hashlib.sha256(args.image.read_bytes()).hexdigest(),model_sha256=hashes,
        bridge_sha256=hashlib.sha256(args.bridge.read_bytes()).hexdigest(),
        native=describe_native(reply['diagnostic']),detections=named_rows(reply['detections']),stderr=proc.stderr)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open('x') as out:out.write(json.dumps(value,indent=2)+'\n')
    print(json.dumps(dict(state=value['state'],jpeg_sha256=value['jpeg_sha256'],detections=value['detections'])))


if __name__=='__main__':main()
