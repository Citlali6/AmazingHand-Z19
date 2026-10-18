"""Compare generated 2020.1 XCI parameters with archived camera XCI, including inactive metadata."""
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

NS = '{http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009}'


def values(path):
    root = ET.parse(path).getroot()
    return {node.attrib[NS + 'referenceId']: node.text or ''
            for node in root.iter(NS + 'configurableElementValue')}


def audit_xci(camera, build, old, new):
    original = camera / 'project/mipi_dp.srcs/sources_1/bd/design_1'
    generated = build / 'vivado/mipi_dp.srcs/sources_1/bd/design_1'
    used = {p for net in old['interface_nets'].values() for p in net['interface_ports']}
    used.update(p for net in old['nets'].values() for p in net['ports'])
    report = {}
    for name, component in old['components'].items():
        if ':module_ref:' in component['vlnv']:
            continue
        a = next(original.rglob(component['xci_name'] + '.xci'))
        b = next(generated.rglob(new['components'][name]['xci_name'] + '.xci'))
        x, y = values(a), values(b)
        differences = []
        for key in sorted(set(x) | set(y)):
            if not key.startswith(('PARAM_VALUE.', 'MODELPARAM_VALUE.', 'BUSIFPARAM_VALUE.')) or x.get(key) == y.get(key):
                continue
            before, after = x.get(key), y.get(key)
            reason = None
            if key in ['PARAM_VALUE.Component_Name', 'MODELPARAM_VALUE.TLM_COMPONENT_NAME']:
                if after == b.stem:
                    reason = 'regenerated instance name; no hardware parameter change'
            elif name == 'ps8_0_axi_periph' and key == 'PARAM_VALUE.NUM_MI' and (before, after) == ('11', '12'):
                reason = 'authorized additional M11 AHIL destination'
            elif name == 'zynq_ultra_ps_e_0':
                parameter = key.removeprefix('PARAM_VALUE.')
                if parameter == 'PSU__PROTECTION__SLAVES':
                    extra = {'FPD;FPD_GPV;FD700000;FD7FFFFF;1', 'FPD;CCI_GPV;FD6E0000;FD6EFFFF;1'}
                    if set(after.replace('\n', '').split('|')) == set(before.replace('\n', '').split('|')) | extra:
                        reason = '2020.1 generated protection metadata; new PS initialization forbidden'
                inactive = {'PSU__M_AXI_GP1__FREQMHZ': ('PSU__USE__M_AXI_GP1', '200.0', '10'),
                            'PSU__M_AXI_GP2__FREQMHZ': ('PSU__USE__M_AXI_GP2', '100.0', '10'),
                            'PSU__S_AXI_GP0__FREQMHZ': ('PSU__USE__S_AXI_GP0', '200.0', '10'),
                            'PSU__S_AXI_GP2__FREQMHZ': ('PSU__USE__S_AXI_GP2', '200.0', '10'),
                            'PSU__S_AXI_GP4__FREQMHZ': ('PSU__USE__S_AXI_GP4', '200.0', '10'),
                            'PSU__S_AXI_GP5__FREQMHZ': ('PSU__USE__S_AXI_GP5', '200.0', '10'),
                            'PSU__SAXIGP0__DATA_WIDTH': ('PSU__USE__S_AXI_GP0', '32', '128')}
                if parameter in inactive:
                    enable, expected_a, expected_b = inactive[parameter]
                    if x['PARAM_VALUE.' + enable] == y['PARAM_VALUE.' + enable] == '0' and (before, after) == (expected_a, expected_b):
                        reason = 'metadata of a disabled PS AXI interface'
                if parameter == 'PSU__NUM_F2P0__INTR__INPUTS' and (before, after) == ('7', '1') and name + '/pl_ps_irq0' not in used:
                    reason = 'unused/unconnected IRQ0 input width; connected IRQ1 unchanged'
            if name == 'xlconcat_3' and re.fullmatch(r'(?:MODEL)?PARAM_VALUE.IN(?:3[2-9]|[4-9][0-9]|1[01][0-9]|12[0-7])_WIDTH', key) and (before, after) == ('1', None):
                if x['PARAM_VALUE.NUM_PORTS'] == y['PARAM_VALUE.NUM_PORTS'] == '6':
                    reason = 'removed metadata for nonexistent inputs >=32; six active inputs unchanged'
            if key.startswith('BUSIFPARAM_VALUE.'):
                interface = key.split('.')[1]
                if name + '/' + interface not in used:
                    reason = 'unconnected/disabled interface descriptor; no connected bus change'
                elif name in ['axi_iic_0', 'axi_iic_1'] and key in [
                        'BUSIFPARAM_VALUE.S_AXI.NUM_READ_OUTSTANDING',
                        'BUSIFPARAM_VALUE.S_AXI.NUM_WRITE_OUTSTANDING'] and (before, after) == ('1', '2'):
                    reason = '2020.1 AXI-IIC outstanding capability metadata; core model parameters unchanged'
            if reason is None:
                raise ValueError('unreviewed 2020.1 XCI difference: %s/%s %r -> %r' %
                                 (name, key, str(before)[:120], str(after)[:120]))
            differences.append(dict(parameter=key, original=before, native=after, reason=reason))
        report[name] = dict(original=str(a), native=str(b), vlnv=component['vlnv'], differences=differences)
    return report
