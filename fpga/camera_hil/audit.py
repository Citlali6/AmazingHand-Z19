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
                tool_required='strict archive: 2020.2; explicit isolated experimental route: 2020.1',
                validation='source inspection only; not Vivado validation')


def connected(design, kind, endpoints, field):
    wanted = set(endpoints)
    return any(wanted <= set(net[field]) for net in design[kind].values())


def build_audit(build):
    old = read_bd(CAMERA / 'project' / BD)
    new = read_bd(build / 'source' / BD)
    native = (build / 'reconstruction.json').exists()
    profile = 'camera-hil-2020.2'
    adaptations = []
    csi_patched = set()
    if native:
        record = json.loads((build / 'reconstruction.json').read_text())
        require(record['profile'] == 'experimental-camera-hil-2020.1' and
                record['tool'] == '2020.1', 'unrecognized reconstruction record')
        require(sha(build / 'rebuild.tcl') == record['prepared_script_sha256'],
                'experimental Tcl changed after preparation')
        require(sha(build / 'source' / BD) == sha(build / 'vivado' / BD),
                'audited BD snapshot differs from the actual native project BD')
        require((build / 'validated.txt').read_text().strip() ==
                'Vivado 2020.1 validate_bd_design returned successfully',
                'actual 2020.1 BD validation evidence missing')
        for name in ['grasp_fsm.sv', 'hand_hil_axi.sv', 'hand_hil_shell.v']:
            require(sha(build / 'hil_rtl' / name) == sha(HERE / 'rtl' / name),
                    'experimental inherited HIL source changed: ' + name)
        profile = record['profile']
        if 'csi_repair' in record:
            from experimental_2020_1.csi_patch import verify_patches
            repair = record['csi_repair']
            require(repair['version'] == 3 and repair['input_hz'] == CLOCK_HZ and
                    repair['output_hz'] == 301055970 and repair['multiplier'] == 6 and
                    repair['divider'] == 4 and repair['reference_reset_cycles'] == 32,
                    'unexpected CSI reference repair')
            csi_patched = verify_patches(CAMERA, build, repair['changes'])
            require(sha(build / 'csi_delay_reference.v') == repair['shared_reference_sha256'] ==
                    sha(HERE / 'experimental_2020_1/csi_delay_reference.v'), 'shared reference RTL changed')
            require(sha(build / 'mipi_nominal.xdc') == repair['nominal_mipi_xdc_sha256'] ==
                    sha(HERE / 'experimental_2020_1/mipi_nominal.xdc'), 'nominal MIPI constraints changed')
            require(sha(build / 'fix_netlist.tcl') == repair['netlist_hook_sha256'] ==
                    sha(HERE / 'experimental_2020_1/fix_netlist.tcl'), 'netlist repair hook changed')
            packed = {}
            for row in repair['changes']:
                if Path(row['path']).suffix not in ['.v', '.vhd']:
                    continue
                hits = list((build / 'vivado' / BD.parent / 'ipshared').rglob(Path(row['path']).name))
                require(len(hits) == 1 and sha(hits[0]) == row['patched_sha256'],
                        'actual packed/synthesized CSI HDL differs: ' + row['path'])
                packed[str(hits[0])] = sha(hits[0])
            adaptations.append(dict(csi_repair=repair, packed_csi_hdl_sha256=packed,
                                    risk='offline experimental; sensor timing/board acceptance required'))
    manifest = json.loads((CAMERA / 'manifest.json').read_text())
    for name, expected in manifest['sha256'].items():
        if name.startswith('project/repo/') or (name.startswith('project/') and
                                                Path(name).suffix in ['.v', '.xdc']):
            if Path(name).relative_to('project').as_posix() in csi_patched:
                continue  # Exact original->private patched bytes already recomputed above.
            require(sha(build / 'source' / Path(name).relative_to('project')) == expected,
                    'copied camera HDL/constraints/IP source changed: ' + name)
    require(old['interface_ports'] == new['interface_ports'], 'camera external ports changed')
    for name, component in old['components'].items():
        require(name in new['components'], 'camera block missing: ' + name)
        target = new['components'][name]
        require(target['vlnv'] == component['vlnv'], 'camera IP version changed: ' + name)
        for key, parameter in component.get('parameters', {}).items():
            expected = '12' if name == 'ps8_0_axi_periph' and key == 'NUM_MI' else parameter['value']
            if native and name == 'zynq_ultra_ps_e_0' and key == 'PSU__PROTECTION__SLAVES':
                actual = value(target, key).split('|')
                original = expected.split('|')
                extra = {'FPD;FPD_GPV;FD700000;FD7FFFFF;1',
                         'FPD;CCI_GPV;FD6E0000;FD6EFFFF;1'}
                require(set(actual) == set(original) | extra and len(actual) == len(original) + 2,
                        'unexpected PS protection-table change')
                adaptations.append(dict(block=name, parameter=key, added=sorted(extra),
                                        risk='tool-derived XSA metadata; never execute new PS initialization'))
                continue
            require(value(target, key) == expected, 'camera parameter changed: ' + name + '/' + key)
    expected_new = {'hil', 'delay_reference'} if csi_patched else {'hil'}
    require(set(new['components']) == set(old['components']) | expected_new, 'unexpected new BD blocks')
    if csi_patched:
        require(new['components']['delay_reference']['vlnv'] == 'xilinx.com:module_ref:csi_delay_reference:1.0',
                'unexpected delay reference module')
        for endpoints in [['zynq_ultra_ps_e_0/pl_clk0', 'delay_reference/clk_pl0'],
                          ['proc_sys_reset_100M/peripheral_reset', 'delay_reference/reset']]:
            require(connected(new, 'nets', endpoints, 'ports'), 'shared reference input missing')
        for shared, port in [('refclk', 'delay_refclock'), ('io_reset', 'io_reset'),
                             ('delay_reset', 'delay_reset'), ('all_ready', 'all_ready')]:
            endpoints = ['delay_reference/' + shared] + ['csi_4lane_raw10_%d/%s' % (i, port) for i in range(4)]
            require(connected(new, 'nets', endpoints, 'ports'), 'shared calibration fanout missing: ' + shared)
        for i in range(4):
            require(connected(new, 'nets', ['csi_4lane_raw10_%d/delay_ready' % i,
                                          'delay_reference/ready%d' % i], 'ports'), 'calibration RDY return missing')
    # Exact endpoint groups reject accidental shorts between preserved nets,
    # extra connections and unreviewed additions; subset containment is weaker.
    expected_scalars = []
    for net in old['nets'].values():
        endpoints = list(net['ports'])
        if 'zynq_ultra_ps_e_0/pl_clk0' in endpoints:
            endpoints += ['hil/clk', 'ps8_0_axi_periph/M11_ACLK']
            if csi_patched:
                endpoints += ['delay_reference/clk_pl0']
        if 'proc_sys_reset_100M/peripheral_aresetn' in endpoints:
            endpoints += ['hil/rst_n', 'ps8_0_axi_periph/M11_ARESETN']
        if csi_patched and 'proc_sys_reset_100M/peripheral_reset' in endpoints:
            endpoints += ['delay_reference/reset']
        expected_scalars.append(frozenset(endpoints))
    if csi_patched:
        for shared, port in [('refclk', 'delay_refclock'), ('io_reset', 'io_reset'),
                             ('delay_reset', 'delay_reset'), ('all_ready', 'all_ready')]:
            expected_scalars.append(frozenset(['delay_reference/' + shared] +
                ['csi_4lane_raw10_%d/%s' % (i, port) for i in range(4)]))
        expected_scalars += [frozenset(['csi_4lane_raw10_%d/delay_ready' % i,
                                      'delay_reference/ready%d' % i]) for i in range(4)]
    actual_scalars = [frozenset(net['ports']) for net in new['nets'].values()]
    require(len(actual_scalars) == len(expected_scalars) and set(actual_scalars) == set(expected_scalars),
            'unexpected scalar connection/short beyond the exact authorized delta')
    expected_interfaces = [frozenset(net['interface_ports']) for net in old['interface_nets'].values()]
    expected_interfaces.append(frozenset(['ps8_0_axi_periph/M11_AXI', 'hil/s_axi']))
    actual_interfaces = [frozenset(net['interface_ports']) for net in new['interface_nets'].values()]
    require(len(actual_interfaces) == len(expected_interfaces) and set(actual_interfaces) == set(expected_interfaces),
            'unexpected interface connection beyond M11/AHIL')
    # All four VDMA address spaces, including exclusions, must stay unchanged.
    require(set(new['addressing']) == set(old['addressing']), 'unexpected new address-space owner')
    for name, address in old['addressing'].items():
        if name != '/zynq_ultra_ps_e_0':
            target = new['addressing'][name]
            if native:
                require(set(target) == set(address), 'DMA address-block fields changed: ' + name)
                require(set(target['address_spaces']) == set(address['address_spaces']),
                        'unexpected DMA address space: ' + name)
                for space, original in address['address_spaces'].items():
                    actual = target['address_spaces'][space]
                    require(actual['segments'] == original['segments'], 'DMA segments changed: ' + name)
                    require(set(actual) == set(original) | {'width', 'range'} and
                            actual['width'] == '64' and actual['range'] == '16E',
                            'unexpected native DMA address-space metadata: ' + name)
            else:
                require(target == address, 'camera DMA address map changed: ' + name)
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
    if native:
        space = new['addressing']['/zynq_ultra_ps_e_0']['address_spaces']['Data']
        original = old['addressing']['/zynq_ultra_ps_e_0']['address_spaces']['Data']
        require(set(space) == set(original) | {'width', 'range'} and
                space['width'] == '40' and space['range'] == '1T', 'unexpected PS address-space metadata')
        from experimental_2020_1.audit_xci import audit_xci
        xci = audit_xci(CAMERA, build, old, new)
        adaptations.append(dict(native_xci_instances=len(xci),
                                reviewed_differences=sum(len(v['differences']) for v in xci.values()),
                                audit_sha256=hashlib.sha256(json.dumps(xci, sort_keys=True).encode()).hexdigest(),
                                risk='native IP implementation and generated metadata require board acceptance'))
    return dict(generated_bd=str(build / 'source' / BD), camera_topology_preserved=True,
                build_profile=profile, adaptations=adaptations, csi_reference_repair=bool(csi_patched),
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
