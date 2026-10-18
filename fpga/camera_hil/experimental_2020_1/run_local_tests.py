"""Run focused vendor-XSim fault tests in a NEW offline output directory."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--vivado', type=Path, default=Path('F:/Xilinx/Vivado/2020.1'))
    args = parser.parse_args()
    out = args.output.resolve()
    if out.exists():
        raise ValueError('refusing existing output directory')
    out.mkdir(parents=True)
    for name in ['csi_clock_detector.vhd', 'csi_cdc_helpers.v', 'csi_delay_reference.v',
                 'test_cdc.sv', 'test_fifo.sv', 'test_reference.sv']:
        shutil.copy2(HERE / name, out / name)
    cmds = []
    def run(tool, *argv):
        cmd = [str(args.vivado / 'bin' / (tool + '.bat')), *map(str, argv)]
        cmds.append(cmd)
        proc = subprocess.run(cmd, cwd=out, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        with (out / 'transcript.txt').open('ab') as log:
            log.write(('COMMAND ' + json.dumps(cmd) + '\n').encode())
            log.write(proc.stdout)
        proc.check_returncode()
    data = args.vivado / 'data'
    run('xvlog', '--sv', data / 'ip/xpm/xpm_cdc/hdl/xpm_cdc.sv',
        data / 'ip/xpm/xpm_memory/hdl/xpm_memory.sv', data / 'ip/xpm/xpm_fifo/hdl/xpm_fifo.sv', '--work', 'xpm')
    run('xvhdl', '--work', 'xpm', data / 'ip/xpm/xpm_VCOMP.vhd')
    run('xvhdl', 'csi_clock_detector.vhd')
    run('xvlog', '--sv', 'csi_cdc_helpers.v', 'csi_delay_reference.v',
        'test_cdc.sv', 'test_fifo.sv', 'test_reference.sv')
    run('xvlog', data / 'verilog/src/glbl.v')
    for top, marker in [('test_cdc', 'PASS_CDC'), ('test_fifo', 'PASS_VENDOR_FIFO'),
                        ('test_reference', 'PASS_REFERENCE')]:
        run('xelab', top, 'glbl', '-L', 'xpm', '-L', 'unisims_ver', '-s', top + '_faults')
        run('xsim', top + '_faults', '-runall', '-log', top + '.log')
        text = (out / (top + '.log')).read_text(encoding='utf-8')
        if marker not in text or 'Fatal:' in text or 'Error:' in text:
            raise ValueError('fault test failed: ' + top)
    manifest = dict(commands=cmds, scope='offline local faults, not sensor/board acceptance',
                    source_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                                   for p in out.iterdir() if p.suffix in ['.v','.vhd','.sv']})
    (out / 'tests.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('PASS: clock/RDY/FIFO/reference faults; ' + str(out))


if __name__ == '__main__':
    main()
