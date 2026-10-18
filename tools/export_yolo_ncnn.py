"""YOLOv8n COCO → NCNN 导出（视觉链模型产物生成，PC 一次性执行）。

产物：新 ``--output-root`` 内的 ``yolov8n_ncnn_model/``（IO=in0/out0，
416 输入 → 3549 anchors）。权重与导出产物不进 Git（.gitignore），
本脚本可从零重建（复现性）。

FP32 首先跑通；本入口不执行尚未验收的 INT8 量化。

运行::

    python tools/export_yolo_ncnn.py --pnnx <pinned-executable> --output-root <new-dir>
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import importlib.metadata
import json
import os
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
WEIGHTS = REPO_ROOT / "yolov8n.pt"
WEIGHTS_URL = 'https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt'


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--imgsz", type=int, default=416)
    parser.add_argument('--output-root', type=Path, default=REPO_ROOT / 'tmp' / 'vision-export')
    parser.add_argument('--weights', type=Path, default=WEIGHTS)
    parser.add_argument('--pnnx', type=Path, required=True, help='explicit pinned converter executable')
    args = parser.parse_args()
    args.output_root = args.output_root.resolve()
    args.weights = args.weights.resolve()
    args.pnnx = args.pnnx.resolve()
    if not args.pnnx.is_file():
        parser.error('--pnnx executable missing')
    # YOLO writes next to its .pt. Work only in a NEW directory, including weights.
    if args.output_root.exists():
        parser.error('--output-root must not exist; choose a new isolated directory')
    args.output_root.mkdir(parents=True)
    weights = args.output_root / 'yolov8n.pt'
    source_kind = 'downloaded_from_upstream'

    if args.weights.exists():
        shutil.copyfile(args.weights, weights)
        source_kind = 'existing_local_weights; upstream URL is expected source only'
    else:
        print(f"weights not found, downloading {weights.name} ...")
        from urllib.request import urlretrieve

        urlretrieve(
            WEIGHTS_URL,
            weights,
        )

    # Keep converter downloads/settings/debug products out of the repo and user profile.
    converter = args.output_root / ('pnnx.exe' if os.name == 'nt' else 'pnnx')
    shutil.copy2(args.pnnx, converter)
    converter.chmod(0o755)
    os.environ['YOLO_CONFIG_DIR'] = str(args.output_root / 'ultralytics-settings')
    os.chdir(args.output_root)
    from ultralytics import YOLO

    out = YOLO(str(weights)).export(
        format="ncnn", imgsz=args.imgsz, half=False, device="cpu"
    )
    directory = Path(out)
    artifacts = {}
    for name in ('model.ncnn.param', 'model.ncnn.bin'):
        path = directory / name
        artifacts[name] = dict(bytes=path.stat().st_size,
                               sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    versions = {name: importlib.metadata.version(name)
                for name in ('ultralytics', 'torch')}
    manifest = dict(model='yolov8n', input_size=args.imgsz, precision='FP32',
                    expected_upstream_source=WEIGHTS_URL, source_kind=source_kind,
                    weights_sha256=hashlib.sha256(weights.read_bytes()).hexdigest(),
                    license='Ultralytics AGPL-3.0 (or separate Enterprise license)',
                    license_url='https://www.ultralytics.com/license',
                    exported_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    tools=versions, tensors={'input':'in0', 'output':'out0', 'head':'decoded 4+80'},
                    converter={'sha256':hashlib.sha256(converter.read_bytes()).hexdigest(),
                               'source_kind':'provided local pinned pnnx executable'},
                    artifacts=artifacts)
    (directory / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f"exported -> {out}")
    print('PC 离线排错（不能替代板端实测）：python tools/test_detect_pc.py '
          '--model-dir "%s" --image <jpg>' % directory)
    return 0


if __name__ == "__main__":
    sys.exit(main())
