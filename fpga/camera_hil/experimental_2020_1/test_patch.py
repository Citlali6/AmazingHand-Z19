"""Protect the private CSI exception against an extra/unreviewed source change."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from csi_patch import ROOT, patch_source, verify_patches

CAMERA = Path(__file__).resolve().parents[2] / 'camera_hw'


class PrivatePatchGate(unittest.TestCase):
    def test_exact_private_patch_passes_and_additional_delta_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='ah-csi-gate-') as folder:
            build = Path(folder)
            source = build / 'source'
            shutil.copytree(CAMERA / 'project' / ROOT, source / ROOT)
            component = ROOT.parent.parent / 'component.xml'
            shutil.copy2(CAMERA / 'project' / component, source / component)
            ledger = patch_source(source)
            self.assertEqual(len(verify_patches(CAMERA, build, ledger)), 7)
            path = source / ROOT / 'csi_4lane_raw10.v'
            path.write_bytes(path.read_bytes() + b'\n// unreviewed delta\n')
            with self.assertRaisesRegex(ValueError, 'differs from exact patch'):
                verify_patches(CAMERA, build, ledger)
            altered = json.loads(json.dumps(ledger))
            altered[0]['patched_sha256'] = '0' * 64
            with self.assertRaisesRegex(ValueError, 'ledger differs'):
                verify_patches(CAMERA, build, altered)


if __name__ == '__main__':
    unittest.main()
