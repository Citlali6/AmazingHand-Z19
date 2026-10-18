#!/usr/bin/env python3
"""Package a completed linux-sd build for RAM-only deployment; no board access."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import zipfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='new package directory')
    parser.add_argument('--bootgen', type=Path, required=True)
    args = parser.parse_args()
    build = args.build.resolve()
    output = args.output.resolve()
    if output.exists() or output.with_suffix('.tar').exists():
        parser.error('refusing existing package directory/archive')
    bd = json.loads((build / 'hand_hil.srcs/sources_1/bd/hand_hil_bd/hand_hil_bd.bd').read_text())
    design = bd['design']
    params = design['components']['ps']['parameters']
    segment = design['addressing']['/ps']['address_spaces']['Data']['segments']['SEG_hil_reg0']
    if not (params['PSU__USE__M_AXI_GP0']['value'] == '1' and
            params['PSU__USE__M_AXI_GP2']['value'] == '0' and
            params['PSU__MAXIGP0__DATA_WIDTH']['value'] == '128' and
            design['components']['hil']['parameters']['CLK_HZ']['value'] == '200703980' and
            int(segment['offset'], 16) == 0xa1000000 and segment['range'] == '4K'):
        parser.error('not the linux-sd HPM0 FPD 128-bit / A1000000 / 200703980Hz build')
    bit = build / 'hand_hil.runs/impl_1/hand_hil_bd_wrapper.bit'
    xsa = build / 'hand_hil.xsa'
    timing = (build / 'timing_impl.rpt').read_text()
    drc = (build / 'drc_impl.rpt').read_text()
    if ('All user specified timing constraints are met.' not in timing or
            not re.search(r'^clk_pl_0\s+\{[^}]+\}\s+4\.982\s+', timing, re.M) or
            not re.search(r'Violations found:\s+0\s', drc)):
        parser.error('passing live-clock timing and DRC reports required')
    with zipfile.ZipFile(xsa) as archive:
        bits = [n for n in archive.namelist() if n.endswith('.bit')]
        if len(bits) != 1 or archive.read(bits[0]) != bit.read_bytes():
            parser.error('XSA does not contain the final bitstream')
    output.mkdir(parents=True)
    # Keep exact build artifacts outside Git and outside original camera trees.
    shutil.copy2(bit, output / 'hand_hil_bd_wrapper.bit')
    shutil.copy2(xsa, output / 'hand_hil.xsa')
    (output / 'hil.bif').write_text('all:\n{\n  hand_hil_bd_wrapper.bit\n}\n', encoding='ascii')
    subprocess.run([str(args.bootgen.resolve()), '-arch', 'zynqmp', '-image', 'hil.bif',
                    '-process_bitstream', 'bin'], cwd=str(output), check=True)
    shutil.copy2(output / 'hand_hil_bd_wrapper.bit.bin', output / 'ah-hil-linux-sd.bin')
    here = Path(__file__).resolve().parent
    runtime = ['hil_server.py', 'linux_hil.py', 'hil-service.sh']
    for name in runtime:
        shutil.copy2(here / 'ps' / name, output / name)
    files = {name: sha(output / name) for name in runtime + ['ah-hil-linux-sd.bin']}
    inputs = {str(path.relative_to(here.parent.parent)): sha(path) for path in
              [here / 'build.tcl', here / 'rtl/hand_hil_shell.v', here / 'rtl/hand_hil_axi.sv',
               here.parent / 'rtl/grasp_fsm.sv', here / 'package_linux.py']}
    manifest = dict(profile='linux-sd', device='xczu19eg-ffvc1760-2-i', tool='Vivado/Vitis 2020.1',
                    base=0xa1000000, clock_hz=200703980, hpm='M_AXI_HPM0_FPD', data_width=128,
                    files_sha256=files, source_sha256=inputs,
                    artifacts_sha256={p.name: sha(p) for p in [bit, xsa]},
                    deployment='manual /run tmpfs; existing camera Linux PS initialization')
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    with tarfile.open(output.with_suffix('.tar'), 'w') as archive:
        for name in runtime + ['ah-hil-linux-sd.bin', 'manifest.json']:
            archive.add(output / name, arcname=output.name + '/' + name)
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
