#!/usr/bin/env python3
"""Explicit experimental 2020.1 reconstruction, never an in-place IP downgrade.

Create a NEW output tree and Tcl from the archived camera BD's public
configuration. Instantiate the same VLNV families in the installed 2020.1
catalog, then restore the original connections/address map and append AHIL.
The archived BD/XCI are inputs only. No upgrade_ip or PS initialization is run.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
UNIFIED = HERE.parent
CAMERA = UNIFIED.parent / 'camera_hw'
BD = Path('mipi_dp.srcs/sources_1/bd/design_1/design_1.bd')


def quote(value):
    value = str(value)
    if any(c in value for c in '{}\\\n\r'):
        raise ValueError('unsupported Tcl braced value: ' + repr(value))
    return '{' + value + '}'


def size(value):
    return int(value[:-1]) * {'K': 1024, 'M': 1024**2, 'G': 1024**3}[value[-1]]


def prepare(output, stage, repair_csi=False):
    if output.exists():
        raise ValueError('refusing existing output: ' + str(output))
    manifest = json.loads((CAMERA / 'manifest.json').read_text())
    for name, expected in manifest['sha256'].items():
        if hashlib.sha256((CAMERA / name).read_bytes()).hexdigest() != expected:
            raise ValueError('original camera input changed: ' + name)
    design = json.loads((CAMERA / 'project' / BD).read_text())['design']
    output.mkdir(parents=True)
    shutil.copytree(CAMERA / 'project', output / 'source')
    shutil.copytree(UNIFIED / 'rtl', output / 'hil_rtl')
    csi_changes = []
    if repair_csi:
        from csi_patch import patch_source
        csi_changes = patch_source(output / 'source')
        shutil.copy2(HERE / 'fix_netlist.tcl', output / 'fix_netlist.tcl')
        shutil.copy2(HERE / 'csi_delay_reference.v', output / 'csi_delay_reference.v')
        shutil.copy2(HERE / 'mipi_nominal.xdc', output / 'mipi_nominal.xdc')
    script = []
    def emit(line):
        script.append(line)
    emit('if {[version -short] ne "2020.1"} {error "Experimental reconstruction requires installed Vivado 2020.1"}')
    emit('set out ' + quote(output.as_posix()))
    emit('create_project mipi_dp [file join $out vivado] -part xczu19eg-ffvc1760-2-i')
    emit('set_property ip_repo_paths [list [file join $out source repo]] [current_project]')
    emit('update_ip_catalog')
    if repair_csi:
        emit('set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]')
    for group, names in manifest['source_groups'].items():
        if group != 'sources_1':
            continue
        for name in names:
            if name.endswith('.bd') or name.endswith('design_1_wrapper.v'):
                continue
            emit('add_files -norecurse [file join $out source ' + quote(name) + ']')
    emit('add_files -norecurse [glob [file join $out hil_rtl *]]')
    if repair_csi:
        emit('add_files -norecurse [file join $out csi_delay_reference.v]')
    emit('update_compile_order -fileset sources_1')
    emit('create_bd_design design_1')
    emit('set catalog [open [file join $out catalog.txt] w]')
    for vlnv in sorted({c['vlnv'] for c in design['components'].values() if ':module_ref:' not in c['vlnv']}):
        emit('set defs [get_ipdefs -all ' + quote(vlnv) + ']')
        emit('puts $catalog "' + vlnv + '\t$defs"')
        emit('if {![llength $defs]} {error "2020.1 catalog missing ' + vlnv + '"}')
    emit('close $catalog')
    emit('set audit [open [file join $out property-audit.txt] w]')
    emit('set unsupported 0')
    conversions = []
    for name, component in design['components'].items():
        vlnv = component['vlnv']
        conversions.append(dict(block=name, original_vlnv=vlnv, native_vlnv=vlnv,
                                operation='recreate from 2020.1 catalog' if ':module_ref:' not in vlnv else 'original HDL module reference'))
        if ':module_ref:' in vlnv:
            emit('create_bd_cell -type module -reference ' + vlnv.split(':')[2] + ' ' + name)
        else:
            emit('create_bd_cell -type ip -vlnv ' + quote(vlnv) + ' ' + name)
        emit('set cell [get_bd_cells ' + name + ']')
        emit('set props [list_property $cell]')
        parameters = component.get('parameters', {})
        for key, parameter in parameters.items():
            emit('if {[lsearch -exact $props CONFIG.' + key + '] < 0} {incr unsupported; puts $audit "MISSING\t' + name + '\t' + key + '\t' + parameter['value'] + '"}')
        properties = ' '.join('CONFIG.' + key + ' ' + quote(p['value']) for key, p in parameters.items())
        if properties:
            emit('if {$unsupported == 0} {')
            emit('if {[catch {set_property -dict [list ' + properties + '] $cell} reason]} {')
            emit('puts $audit "SET_FAILED\t' + name + '\t$reason"; close $audit; error $reason')
            emit('} else {puts $audit "SET_OK\t' + name + '\t' + str(len(parameters)) + ' original parameters"}}')
    emit('close $audit')
    emit('if {$unsupported} {error "Unsupported archived parameters: $unsupported; see property-audit.txt"}')
    if stage == 'probe':
        emit('save_bd_design')
        emit('report_ip_status -file [file join $out ip_status.rpt]')
        emit('puts "EXPERIMENTAL_2020_1_PROPERTY_PROBE_DONE; not BD validation"')
        emit('exit')
    else:
        emit('set_property CONFIG.NUM_MI 12 [get_bd_cells ps8_0_axi_periph]')
        emit('create_bd_cell -type module -reference hand_hil_shell hil')
        emit('set_property CONFIG.CLK_HZ 200703980 [get_bd_cells hil]')
        if repair_csi:
            emit('create_bd_cell -type module -reference csi_delay_reference delay_reference')
        for name, port in design['interface_ports'].items():
            emit('create_bd_intf_port -mode ' + port['mode'] + ' -vlnv ' + quote(port['vlnv']) + ' ' + name)
        for name, net in design['interface_nets'].items():
            endpoints = ['[get_bd_intf_' + ('pins' if '/' in p else 'ports') + ' ' + quote(p) + ']' for p in net['interface_ports']]
            emit('connect_bd_intf_net -intf_net ' + quote(name) + ' ' + ' '.join(endpoints))
        emit('connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M11_AXI] [get_bd_intf_pins hil/s_axi]')
        for name, net in design['nets'].items():
            endpoints = list(net['ports'])
            if 'zynq_ultra_ps_e_0/pl_clk0' in endpoints:
                endpoints += ['hil/clk', 'ps8_0_axi_periph/M11_ACLK']
                if repair_csi:
                    endpoints += ['delay_reference/clk_pl0']
            if repair_csi and 'proc_sys_reset_100M/peripheral_reset' in endpoints:
                endpoints += ['delay_reference/reset']
            if 'proc_sys_reset_100M/peripheral_aresetn' in endpoints:
                endpoints += ['hil/rst_n', 'ps8_0_axi_periph/M11_ARESETN']
            pins = ['[get_bd_' + ('pins' if '/' in p else 'ports') + ' ' + quote(p) + ']' for p in endpoints]
            emit('connect_bd_net -net ' + quote(name) + ' ' + ' '.join(pins))
        if repair_csi:
            for shared, port in [('refclk', 'delay_refclock'), ('io_reset', 'io_reset'),
                                 ('delay_reset', 'delay_reset'), ('all_ready', 'all_ready')]:
                emit('connect_bd_net [get_bd_pins delay_reference/' + shared + '] ' +
                     ' '.join('[get_bd_pins csi_4lane_raw10_%d/%s]' % (i, port) for i in range(4)))
            for i in range(4):
                emit('connect_bd_net [get_bd_pins csi_4lane_raw10_%d/delay_ready] [get_bd_pins delay_reference/ready%d]' % (i, i))
        for owner, block in design['addressing'].items():
            for space, address_space in block['address_spaces'].items():
                for name, bank in address_space['segments'].items():
                    command = ('assign_bd_address -offset ' + bank['offset'] + ' -range ' + bank['range'] +
                               ' -target_address_space [get_bd_addr_spaces ' + quote(owner + '/' + space) +
                               '] [get_bd_addr_segs ' + quote(bank['address_block']) + ']')
                    if bank.get('is_excluded') == 'TRUE':
                        command = ('exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces ' +
                                   quote(owner + '/' + space) + '] [get_bd_addr_segs ' + quote(bank['address_block']) + ']')
                    emit(command)
        emit('assign_bd_address -offset 0xA1000000 -range 4K -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs -of_objects [get_bd_intf_pins hil/s_axi]]')
        emit('validate_bd_design')
        emit('save_bd_design')
        emit('file copy -force [get_property NAME [get_files design_1.bd]] [file join $out source ' + quote(BD.as_posix()) + ']')
        emit('write_bd_tcl [file join $out camera_hil_bd.tcl]')
        emit('report_ip_status -file [file join $out ip_status.rpt]')
        emit('set f [open [file join $out validated.txt] w]; puts $f "Vivado 2020.1 validate_bd_design returned successfully"; close $f')
        emit('generate_target all [get_files design_1.bd]')
        emit('add_files -norecurse [file join $out source ' + quote((BD.parent / 'hdl/design_1_wrapper.v').as_posix()) + ']')
        for name in manifest['source_groups']['constrs_1']:
            emit('add_files -fileset constrs_1 -norecurse [file join $out source ' + quote(name) + ']')
        if repair_csi:
            emit('add_files -fileset constrs_1 -norecurse [file join $out mipi_nominal.xdc]')
        emit('set_property top design_1_wrapper [current_fileset]')
        emit('update_compile_order -fileset sources_1')
        if stage in ['synth', 'impl']:
            emit('launch_runs synth_1 -jobs 4')
            emit('wait_on_run synth_1')
            emit('if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "experimental synthesis failed"}')
            emit('open_run synth_1')
            emit('report_utilization -file [file join $out utilization_synth.rpt]')
            if stage != 'impl':
                emit('close_design')
        if stage == 'impl':
            # Constrain both clocks at the unchanged board's measured profile.
            xdc = []
            for i, period in [(0, 1e9 / 200703980), (1, 2e9 / 200703980)]:
                # XDC is not general Tcl. Assert in ordinary Tcl while the
                # original constraints are loaded, and reuse the original
                # clock source instead of matching two hierarchical aliases.
                emit('set clk [get_clocks clk_pl_' + str(i) + ']')
                emit('if {[llength $clk] != 1 || [llength [get_property SOURCE_PINS $clk]] != 1} {error "Expected original single-source PS clock"}')
                emit('puts "ORIGINAL_CLOCK_SOURCE clk_pl_' + str(i) + ' [get_property SOURCE_PINS $clk]"')
                xdc += ['create_clock -name clk_pl_%d -period %.12f [get_property SOURCE_PINS [get_clocks clk_pl_%d]]' % (i, period, i)]
            (output / 'live_clock.xdc').write_bytes(('\n'.join(xdc) + '\n').encode())
            emit('close_design')
            emit('add_files -fileset constrs_1 -norecurse [file join $out live_clock.xdc]')
            emit('set_property USED_IN_SYNTHESIS false [get_files live_clock.xdc]')
            emit('set_property PROCESSING_ORDER LATE [get_files live_clock.xdc]')
            if repair_csi:
                emit('set_property STEPS.OPT_DESIGN.TCL.POST [file join $out fix_netlist.tcl] [get_runs impl_1]')
                emit('set_property STEPS.ROUTE_DESIGN.TCL.POST [file join $out fix_netlist.tcl] [get_runs impl_1]')
            emit('launch_runs impl_1 -to_step write_bitstream -jobs 4')
            emit('wait_on_run impl_1')
            emit('if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "experimental implementation failed"}')
            emit('open_run impl_1')
            emit('report_clocks -file [file join $out clocks_impl.rpt]')
            emit('set cf [open [file join $out clock_sources.txt] w]')
            for i in [0, 1]:
                emit('set clk [get_clocks clk_pl_' + str(i) + ']')
                emit('if {[llength $clk] != 1 || [llength [get_property SOURCE_PINS $clk]] != 1} {error "Final PL clock must have one source"}')
                emit('puts $cf "clk_pl_' + str(i) + '\t[get_property PERIOD $clk]\t[get_property SOURCE_PINS $clk]"')
            emit('close $cf')
            emit('report_timing_summary -report_unconstrained -file [file join $out timing_impl.rpt]')
            if repair_csi:
                emit('check_timing -verbose -file [file join $out coverage_details.rpt]')
                emit('report_cdc -details -file [file join $out cdc_impl.rpt]')
                emit('report_bus_skew -file [file join $out bus_skew_impl.rpt]')
                emit('report_timing -delay_type min_max -max_paths 40 -nworst 2 -file [file join $out paths_impl.rpt]')
                emit('set pf [open [file join $out delay_primitives.txt] w]')
                emit('foreach c [get_cells -hier -filter {REF_NAME == IDELAYCTRL}] {puts $pf "$c REFCLK=[get_clocks -of_objects [get_pins $c/REFCLK]]"}')
                emit('foreach c [get_cells -hier -filter {REF_NAME == IDELAYE3}] {puts $pf "$c FORMAT=[get_property DELAY_FORMAT $c] REFCLK_MHZ=[get_property REFCLK_FREQUENCY $c]"}')
                emit('close $pf')
            emit('report_drc -file [file join $out drc_impl.rpt]')
            emit('report_methodology -file [file join $out methodology_impl.rpt]')
            emit('write_hw_platform -fixed -include_bit [file join $out camera_hil.xsa]')
        emit('puts "EXPERIMENTAL_CAMERA_HIL_DONE stage=' + stage + '; not board validated"')
    (output / 'rebuild.tcl').write_bytes(('\n'.join(script) + '\n').encode())
    record = dict(profile='experimental-camera-hil-2020.1', original='2020.2_AR75986',
                  tool='2020.1', stage=stage, original_camera_manifest=manifest,
                  conversions=conversions, safety='offline only; no PS/DDR/SD/driver changes',
                  prepared_script_sha256=hashlib.sha256((output / 'rebuild.tcl').read_bytes()).hexdigest())
    if repair_csi:
        record['csi_repair'] = dict(version=3, changes=csi_changes,
            input_hz=200703980, multiplier=6, divider=4, output_hz=301055970,
            minimum_idelayctrl_reset_ns=52, reference_reset_cycles=32,
            shared_reference_sha256=hashlib.sha256((output / 'csi_delay_reference.v').read_bytes()).hexdigest(),
            nominal_mipi_xdc_sha256=hashlib.sha256((output / 'mipi_nominal.xdc').read_bytes()).hexdigest(),
            netlist_hook_sha256=hashlib.sha256((output / 'fix_netlist.tcl').read_bytes()).hexdigest(),
            assumptions='PS clock unchanged; MIPI external timing remains unqualified')
    (output / 'reconstruction.json').write_bytes((json.dumps(record, indent=2) + '\n').encode())
    print(str(output / 'rebuild.tcl'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--stage', choices=['probe', 'validate', 'synth', 'impl'], default='probe')
    parser.add_argument('--repair-csi', action='store_true', help='explicit private local-reference/CDC/netlist experiment')
    args = parser.parse_args()
    prepare(args.output.resolve(), args.stage, args.repair_csi)


if __name__ == '__main__':
    main()
