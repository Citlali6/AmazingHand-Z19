#!/usr/bin/env python3
"""Package an audited Vivado 2020.2 implementation. Offline only; no deployment."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile

from audit import HERE, CAMERA, CLOCK_HZ, build_audit, require, sha, source_audit

CAMERA_SHA = 'e25e9bc7fd4c2008c7a198a91bc4937716b333259d08da7ed777d8ffe9b3384b'


def check_reports(build):
    timing = (build / 'timing_impl.rpt').read_text()
    drc = (build / 'drc_impl.rpt').read_text()
    for report in [timing, drc]:
        require(re.search(r'Tool Version\s*:\s*Vivado v\.2020\.2\b', report), 'reports need Vivado 2020.2')
        require(re.search(r'Design\s*:\s*design_1_wrapper\b', report), 'wrong report design')
    require('All user specified timing constraints are met.' in timing, 'timing constraints failed')
    require(re.search(r'Violations found:\s+0\s', drc), 'DRC must have zero violations')
    for clock, expected in [('clk_pl_0', 1e9 / CLOCK_HZ), ('clk_pl_1', 2e9 / CLOCK_HZ)]:
        match = re.search(r'^' + clock + r'\s+\{[^}]+\}\s+([0-9.]+)\s+', timing, re.M)
        require(match and abs(float(match[1]) - expected) < .001,
                'timing report must use live period: ' + clock)
    for check in ['no_clock', 'unconstrained_internal_endpoints', 'no_input_delay',
                  'no_output_delay', 'multiple_clock', 'generated_clocks', 'loops',
                  'partial_input_delay', 'partial_output_delay', 'latch_loops']:
        require(re.search(r'checking ' + check + r' \(0\)', timing), 'timing coverage failed: ' + check)


def convert(bootgen, output, stem):
    (output / (stem + '.bif')).write_text('all:\n{\n  [destination_device=pl] ' + stem + '.bit\n}\n', encoding='ascii')
    subprocess.run([str(bootgen), '-arch', 'zynqmp', '-image', stem + '.bif',
                    '-process_bitstream', 'bin'], cwd=str(output), check=True)
    shutil.copy2(output / (stem + '.bit.bin'), output / (stem + '.bin'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='new amazinghand-camera-hil-* directory')
    parser.add_argument('--bootgen', type=Path, required=True)
    args = parser.parse_args()
    build, output = args.build.resolve(), args.output.resolve()
    require(not output.exists() and not output.with_suffix('.tar').exists(), 'output already exists')
    require(output.name.startswith('amazinghand-camera-hil-'), 'unsafe package directory name')
    require(args.bootgen.is_file(), 'Bootgen executable missing')
    sources = source_audit()
    topology = build_audit(build)
    check_reports(build)
    bit = build / 'vivado/mipi_dp.runs/impl_1/design_1_wrapper.bit'
    xsa = build / 'camera_hil.xsa'
    with zipfile.ZipFile(xsa) as archive:
        bits = [n for n in archive.namelist() if n.endswith('.bit')]
        require(len(bits) == 1 and archive.read(bits[0]) == bit.read_bytes(), 'bit/XSA mismatch')
    # Nothing is created until the build, source, topology, timing and DRC gates pass.
    output.mkdir(parents=True)
    shutil.copy2(bit, output / 'camera-hil.bit')
    shutil.copy2(xsa, output / 'camera_hil.xsa')
    shutil.copy2(CAMERA / 'validated/design_1_wrapper.bit', output / 'camera-original.bit')
    for stem in ['camera-hil', 'camera-original']:
        convert(args.bootgen.resolve(), output, stem)
    require(sha(output / 'camera-original.bin') == CAMERA_SHA, 'original camera conversion hash mismatch')
    runtime = ['unified.py', 'hil_server.py']
    for name in runtime:
        shutil.copy2(HERE / 'ps' / name, output / name)
    names = runtime + ['camera-hil.bin', 'camera-original.bin']
    inputs = [p for p in HERE.rglob('*') if p.suffix in ['.py', '.sv', '.v', '.tcl', '.json']
              and 'evidence' not in p.parts and '__pycache__' not in p.parts]
    manifest = dict(profile='camera-hil/1', device='xczu19eg-ffvc1760-2-i',
                    base=0xa1000000, clock_hz=CLOCK_HZ, data_width=128,
                    files_sha256={n: sha(output / n) for n in names},
                    source_sha256={p.relative_to(HERE).as_posix(): sha(p) for p in inputs},
                    artifacts_sha256={p.name: sha(p) for p in [bit, xsa]},
                    source_audit=sources, build_audit=topology,
                    deployment='RAM-only; explicit human-approved PL load; no PS/FSBL/SD updates')
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    with tarfile.open(output.with_suffix('.tar'), 'w') as archive:
        # XSA is retained on the PC only. Never deploy its PS initialization.
        for name in names + ['manifest.json']:
            archive.add(output / name, arcname=output.name + '/' + name)
    print(json.dumps(dict(package=str(output.with_suffix('.tar')),
                          sha256=sha(output.with_suffix('.tar'))), indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        sys.exit('UNIFIED_PACKAGE_REFUSED: ' + str(error))
