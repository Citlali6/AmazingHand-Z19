"""Vosk 中文命令词小模型下载（host/models/，不入 Git，脚本可重建）。

运行::

    python tools/download_vosk_model.py
"""

from __future__ import annotations

import io
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MODELS_DIR = REPO_ROOT / "host/models"
URL = "https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip"
NAME = "vosk-model-small-cn-0.22"


def main() -> int:
    target = MODELS_DIR / NAME
    if target.exists():
        print(f"already exists: {target}")
        return 0
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    print(f"downloading {URL} (~42 MiB) ...")
    buf = urllib.request.urlopen(URL).read()  # noqa: S310 —— 固定官方地址
    zipfile.ZipFile(io.BytesIO(buf)).extractall(MODELS_DIR)
    print(f"extracted -> {target}")
    return 0


if __name__ == "__main__":
    import urllib.request  # noqa: E402

    sys.exit(main())
