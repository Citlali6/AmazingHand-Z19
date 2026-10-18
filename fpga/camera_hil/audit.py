#!/usr/bin/env python3
"""Audit camera provenance and, optionally, a generated unified BD. No Vivado/board IO."""
import argparse
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
CAMERA = HERE.parent / 'camera_hw'
BD = Path('mipi_dp.srcs/sources_1/bd/design_1/design_1.bd')
BASE = 0xa1000000
CLOCK_HZ = 200703980


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def size(value):
    suffix = value[-1].upper()
    return int(value[:-1]) * {'K': 1024, 'M': 1024**2, 'G': 1024**3}[suffix]


def read_bd(path):
    return json.loads(path.read_text())['design']


def segments(design):
    return design['addressing']['/zynq_ultra_ps_e_0']['address_spaces']['Data']['segments']


def value(component, name):
    return component['parameters'][name]['value']


def source_audit():
    manifest = json.loads((CAMERA / 'manifest.json').read_text())
    for name, expected in manifest['sha256'].items():
        require(sha(CAMERA / name) == expected, 'camera archive changed: ' + name)
    origin = json.loads((HERE / 'provenance.json').read_text())
    for entry in origin['files']:
        require(sha(HERE / entry['target']) == entry['sha256'],
                'inherited PR #13 file changed: ' + entry['target'])
    design = read_bd(CAMERA / 'project' / BD)
    ps = design['components']['zynq_ultra_ps_e_0']
    for name, expected in [('PSU__USE__M_AXI_GP0', '1'),
                           ('PSU__MAXIGP0__DATA_WIDTH', '128'),
                           ('PSU__USE__S_AXI_GP3', '1'),
                           ('PSU__SAXIGP3__DATA_WIDTH', '128')]:
        require(value(ps, name) == expected, 'wrong archived PS profile: ' + name)
    require(value(design['components']['ps8_0_axi_periph'], 'NUM_MI') == '11',
            'wrong archived interconnect')
    banks = segments(design)
    for name, bank in banks.items():
        low = int(bank['offset'], 16)
        require(low + size(bank['range']) <= BASE or low >= BASE + 4096,
                'AHIL address collides with ' + name)
    return dict(camera_files_verified=len(manifest['sha256']),
                inherited_files_verified=len(origin['files']),
                inherited_pr=origin['pr'], inherited_commit=origin['commit'],
                camera_addresses={name: dict(offset=b['offset'], range=b['range'])
                                  for name, b in banks.items()},
                new_hil=dict(base=hex(BASE), size=4096, clock_hz=CLOCK_HZ),
                ip_vlnv=sorted({c['vlnv'] for c in design['components'].values()}),
                tool_required='Vivado 2020.2; original camera 2020.2_AR75986',
                validation='source inspection only; not Vivado validation')


def connected(design, kind, endpoints, field):
    wanted = set(endpoints)
    return any(wanted <= set(net[field]) for net in design[kind].values())


def build_audit(build):
    old = read_bd(CAMERA / 'project' / BD)
    new = read_bd(build / 'source' / BD)
    manifest = json.loads((CAMERA / 'manifest.json').read_text())
    for name, expected in manifest['sha256'].items():
        if name.startswith('project/repo/') or (name.startswith('project/') and
                                                Path(name).suffix in ['.v', '.xdc']):
            require(sha(build / 'source' / Path(name).relative_to('project')) == expected,
                    'copied camera HDL/constraints/IP source changed: ' + name)
    require(old['interface_ports'] == new['interface_ports'], 'camera external ports changed')
    for name, component in old['components'].items():
        require(name in new['components'], 'camera block missing: ' + name)
        target = new['components'][name]
        require(target['vlnv'] == component['vlnv'], 'camera IP version changed: ' + name)
        for key, parameter in component.get('parameters', {}).items():
            expected = '12' if name == 'ps8_0_axi_periph' and key == 'NUM_MI' else parameter['value']
            require(value(target, key) == expected, 'camera parameter changed: ' + name + '/' + key)
    require(set(new['components']) == set(old['components']) | {'hil'}, 'unexpected new BD blocks')
    for kind, field in [('nets', 'ports'), ('interface_nets', 'interface_ports')]:
        for name, net in old[kind].items():
            require(connected(new, kind, net[field], field), 'camera connection changed: ' + name)
    # All four VDMA address spaces, including exclusions, must stay unchanged.
    for name, address in old['addressing'].items():
        if name != '/zynq_ultra_ps_e_0':
            require(new['addressing'][name] == address, 'camera DMA address map changed: ' + name)
    banks = segments(new)
    for name, bank in segments(old).items():
        require(banks[name] == bank, 'camera register address changed: ' + name)
    added = set(banks) - set(segments(old))
    require(len(added) == 1, 'expected one new AHIL segment')
    bank = banks[added.pop()]
    require(int(bank['offset'], 16) == BASE and size(bank['range']) == 4096 and
            bank['address_block'].startswith('/hil/'), 'wrong AHIL address segment')
    require(value(new['components']['hil'], 'CLK_HZ') == str(CLOCK_HZ), 'wrong AHIL watchdog clock')
    require(connected(new, 'interface_nets', ['ps8_0_axi_periph/M11_AXI', 'hil/s_axi'], 'interface_ports'),
            'AHIL AXI connection missing')
    for endpoints in [['zynq_ultra_ps_e_0/pl_clk0', 'hil/clk', 'ps8_0_axi_periph/M11_ACLK'],
                      ['proc_sys_reset_100M/peripheral_aresetn', 'hil/rst_n',
                       'ps8_0_axi_periph/M11_ARESETN']]:
        require(connected(new, 'nets', endpoints, 'ports'), 'AHIL clock/reset connection missing')
    return dict(generated_bd=str(build / 'source' / BD), camera_topology_preserved=True,
                hil_axilite_connected=True, generated_bd_sha256=sha(build / 'source' / BD))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path)
    args = parser.parse_args()
    result = source_audit()
    if args.build:
        result['build'] = build_audit(args.build.resolve())
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
