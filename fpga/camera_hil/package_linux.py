#!/usr/bin/env python3
"""Package a strictly audited 2020.2 or explicit experimental 2020.1 implementation."""
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


def check_cdc(build, tool='2020.1'):
    """The new multi-domain reference repair also requires a real CDC signoff."""
    report = (build / 'cdc_impl.rpt').read_text(encoding='utf-8')
    require(re.search(r'Tool Version\s*:\s*Vivado v\.' + re.escape(tool) + r'\b', report)
            and re.search(r'Design\s*:\s*design_1_wrapper\b', report), 'wrong/missing CDC report provenance')
    summary = report.split('Source Clock:', 1)[0]
    rows = re.findall(r'^CDC-\d+\s+(Critical|Warning|Info)\s+(\d+)\s+', summary, re.M)
    require(rows, 'CDC summary rows missing')
    critical = sum(int(count) for severity, count in rows if severity == 'Critical')
    require(critical == 0, 'CDC signoff failed: %d Critical findings' % critical)


def check_bus_skew(build, tool='2020.1'):
    """XPM Gray pointers carry instance-scoped bus-skew constraints too."""
    report = (build / 'bus_skew_impl.rpt').read_text(encoding='utf-8')
    require(re.search(r'Tool Version\s*:\s*Vivado v\.' + re.escape(tool) + r'\b', report)
            and re.search(r'Design\s*:\s*design_1_wrapper\b', report), 'wrong/missing bus-skew report provenance')
    slacks = re.findall(r'Slack \((MET|VIOLATED)\)\s*:\s*([-0-9.]+)ns', report)
    require(slacks and all(status == 'MET' and float(value) >= 0 for status, value in slacks),
            'bus-skew signoff failed or missing')


def check_reports(build, tool='2020.2', require_sources=False):
    require(tool in ['2020.1', '2020.2'], 'unsupported report tool profile')
    timing = (build / 'timing_impl.rpt').read_text()
    drc = (build / 'drc_impl.rpt').read_text()
    for report in [timing, drc]:
        require(re.search(r'Tool Version\s*:\s*Vivado v\.' + re.escape(tool) + r'\b', report),
                'reports need Vivado ' + tool)
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
    if require_sources:
        require((build / 'clocks_impl.rpt').is_file(), 'actual report_clocks missing')
        rows = [line.split('\t') for line in (build / 'clock_sources.txt').read_text().splitlines()]
        require(len(rows) == 2 and {row[0] for row in rows} == {'clk_pl_0', 'clk_pl_1'},
                'expected exactly two proven single-source PL clocks')
        for row in rows:
            require(len(row) == 3 and len(row[2].split()) == 1, 'clock source must be unique')
            period = (1 if row[0] == 'clk_pl_0' else 2) * 1e9 / CLOCK_HZ
            require(abs(float(row[1]) - period) < .001, 'final clock-source period mismatch')


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
    parser.add_argument('--reports', type=Path, help='separate corrected implementation result directory')
    args = parser.parse_args()
    build, output = args.build.resolve(), args.output.resolve()
    require(not output.exists() and not output.with_suffix('.tar').exists(), 'output already exists')
    require(output.name.startswith('amazinghand-camera-hil-'), 'unsafe package directory name')
    require(args.bootgen.is_file(), 'Bootgen executable missing')
    sources = source_audit()
    topology = build_audit(build)
    tool = '2020.1' if topology['build_profile'] == 'experimental-camera-hil-2020.1' else '2020.2'
    reports = args.reports.resolve() if args.reports else build
    run = 'impl_1'
    if reports != build:
        require(tool == '2020.1', 'separate reports supported only for explicit native experiment')
        record = json.loads((reports / 'implementation.json').read_text())
        require(Path(record['build']).resolve() == build and record['implementation_run'] == 'impl_liveclock',
                'repair results do not belong to this build/run')
        require(sha(reports / 'repair_clock_executed.tcl') ==
                sha(HERE / 'experimental_2020_1/repair_clock.tcl'), 'executed repair Tcl differs from reviewed source')
        run = record['implementation_run']
    check_reports(reports, tool=tool, require_sources=(tool == '2020.1'))
    if topology['csi_reference_repair']:
        check_cdc(reports, tool=tool)
        check_bus_skew(reports, tool=tool)
    bit = build / ('vivado/mipi_dp.runs/' + run + '/design_1_wrapper.bit')
    xsa = reports / 'camera_hil.xsa'
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
    inputs = [p for p in HERE.rglob('*') if p.suffix in ['.py', '.sv', '.v', '.vhd', '.tcl', '.xdc', '.json']
              and 'evidence' not in p.parts and '__pycache__' not in p.parts]
    manifest = dict(profile='camera-hil/1', build_profile=topology['build_profile'], tool=tool,
                    implementation_run=run, report_directory=str(reports),
                    device='xczu19eg-ffvc1760-2-i',
                    base=0xa1000000, clock_hz=CLOCK_HZ, data_width=128,
                    files_sha256={n: sha(output / n) for n in names},
                    source_sha256={p.relative_to(HERE).as_posix(): sha(p) for p in inputs},
                    artifacts_sha256={p.name: sha(p) for p in [bit, xsa]},
                    reports_sha256={p.name: sha(p) for p in reports.iterdir()
                                    if p.name.endswith('.rpt') or p.name in ['implementation.json', 'clock_sources.txt', 'delay_primitives.txt', 'repair_clock_executed.tcl']},
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
