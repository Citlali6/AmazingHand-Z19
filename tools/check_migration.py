"""Verify shipped migration assets; optional local model load, never board I/O."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', action='store_true', help='Load the local MuJoCo model; no FPGA access')
    args = parser.parse_args()
    try:
        model = json.loads((ROOT / 'docs/migration/model-snapshot.json').read_text(encoding='utf-8'))
        for item in model['files']:
            if digest(ROOT / item['path']) != item['sha256']:
                raise ValueError('Model hash mismatch: ' + item['path'])
        archives = [ROOT / 'deliverables/voice_usb/voice_usb_package_20261018_v2.zip',
                    ROOT / 'deliverables/mjc1_fpd/mjc1_fpd_r2_20261018.zip']
        for archive in archives:
            expected = archive.with_name(archive.name + '.sha256').read_text().split()[0]
            if digest(archive) != expected:
                raise ValueError('Archive hash mismatch: ' + archive.name)
            with zipfile.ZipFile(archive) as data:
                if data.testzip() is not None:
                    raise ValueError('Invalid ZIP content: ' + archive.name)
        with zipfile.ZipFile(archives[1]) as data:
            manifest = json.loads(data.read('fpga/mjc1_fpd/out/manifest_r2.json'))
            for name, expected in manifest['hashes'].items():
                if hashlib.sha256(data.read('fpga/mjc1_fpd/out/' + name)).hexdigest() != expected:
                    raise ValueError('Firmware hash mismatch: ' + name)
            if digest(ROOT / 'fpga/mjc1_fpd/mmio.c') != manifest['native_mmio_source_sha256']:
                raise ValueError('Native MMIO source hash mismatch')
        result = dict(model_files=len(model['files']), archives=len(archives),
                      asset_integrity='passed', board_access='not_attempted')
        discussion_root = ROOT / 'docs/migration/upstream_archive_20261019_v2'
        discussion_manifest = json.loads((discussion_root / 'archive_manifest.json').read_text(encoding='utf-8'))
        for name, item in discussion_manifest['files'].items():
            path = (discussion_root / name).resolve()
            if discussion_root.resolve() not in path.parents or digest(path) != item['sha256']:
                raise ValueError('Discussion archive hash mismatch: ' + name)
        counts = discussion_manifest['counts']
        result.update(discussion_records=counts['issues'] + counts['pull_requests'],
                      discussion_integrity='passed')
        local_root = ROOT / 'deliverables/local_sources'
        snapshots = json.loads((local_root / 'snapshots.json').read_text(encoding='utf-8'))
        for item in snapshots:
            path = local_root / item['archive']
            if digest(path) != item['archive_sha256']:
                raise ValueError('Local source snapshot hash mismatch: ' + path.name)
            with zipfile.ZipFile(path) as data:
                if data.testzip() is not None:
                    raise ValueError('Local source snapshot ZIP error: ' + path.name)
                for source in item['files']:
                    if hashlib.sha256(data.read('source/' + source['path'])).hexdigest() != source['sha256']:
                        raise ValueError('Local source file hash mismatch: ' + source['path'])
        legacy = json.loads((local_root / 'legacy-configs-manifest.json').read_text(encoding='utf-8'))
        if digest(local_root / legacy['archive']) != legacy['sha256']:
            raise ValueError('Legacy generated configuration archive hash mismatch')
        with zipfile.ZipFile(local_root / legacy['archive']) as data:
            snapshot = json.loads(data.read('snapshot.json'))
            if len(snapshot['files']) != legacy['source_files']:
                raise ValueError('Legacy generated configuration file count mismatch')
            for item in snapshot['files']:
                if hashlib.sha256(data.read('source/' + item['path'])).hexdigest() != item['sha256']:
                    raise ValueError('Legacy generated configuration file mismatch: ' + item['path'])
        result.update(local_source_archives=len(snapshots) + 1,
                      legacy_configuration_files=legacy['source_files'])
        if args.runtime:
            import mujoco
            path = ROOT / 'AmazingHand/Demo/AHSimulation/AHSimulation/AH_Right/mjcf/scene.xml'
            hand = mujoco.MjModel.from_xml_path(str(path))
            if hand.nu != 8:
                raise ValueError('Expected eight hand actuators')
            result.update(mujoco=mujoco.__version__, actuators=hand.nu, model_load='passed')
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, ValueError, ImportError, zipfile.BadZipFile) as exc:
        print('MIGRATION_CHECK_FAILED: ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
