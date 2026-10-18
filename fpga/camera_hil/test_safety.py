"""Regression checks for reload rejection/order. No board access or old HIL simulation."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('unified', HERE / 'ps/unified.py')
unified = importlib.util.module_from_spec(spec)
spec.loader.exec_module(unified)
sys.path.insert(0, str(HERE))
from package_linux import check_reports


class Safety(unittest.TestCase):
    def test_reload_rejects_loaded_camera_even_without_capture(self):
        with self.assertRaisesRegex(RuntimeError, 'camera driver loaded'):
            unified.reject_active_users({'ah_camera0'}, [], [])

    def test_reload_rejects_bound_dma_driver_and_surviving_mmap(self):
        with self.assertRaisesRegex(RuntimeError, 'bound PL driver'):
            unified.reject_active_users(set(), [('a0060000.dma', True)], [])
        with self.assertRaisesRegex(RuntimeError, 'active PL/device mappings'):
            unified.reject_active_users(set(), [], ['123:mmap'])

    def test_dma_halt_failure_remains_blocking_after_driver_unload(self):
        with self.assertRaisesRegex(RuntimeError, 'DMA halt failure'):
            unified.reject_dma_fault('ah_camera0: refusing to free unhalted DMA memory; power cycle required')

    def test_reload_requires_human_approval_before_any_probe(self):
        with patch.object(unified, 'preflight') as probe, patch.object(unified, 'program') as program:
            for action in ['run', 'restore-camera']:
                with self.assertRaisesRegex(RuntimeError, 'approval'):
                    unified.approved_action(action, False, {}, '', 0)
            probe.assert_not_called()
            program.assert_not_called()

    def test_failed_load_never_opens_ahil_bank(self):
        module = types.SimpleNamespace(PlDevice=unittest.mock.Mock())
        with patch.dict(sys.modules, {'hil_server': module}), \
                patch.object(unified, 'preflight', return_value={}), \
                patch.object(unified, 'program', side_effect=RuntimeError('load failed')):
            with self.assertRaisesRegex(RuntimeError, 'load failed'):
                unified.approved_action('run', True, {'base': 0xa1000000}, '', 0)
            module.PlDevice.assert_not_called()

    def test_camera_allowed_during_same_loaded_service_session(self):
        events = []
        device = unittest.mock.Mock()
        device.snapshot.return_value = {'torque_enabled': False}
        module = types.SimpleNamespace(PlDevice=lambda base: events.append('open-ahil') or device)
        def serve(*args):
            # Camera can be started AFTER load. No second reload preflight is
            # allowed here: it would incorrectly reject the desired dual mode.
            events.append('serve-with-camera')
        with patch.dict(sys.modules, {'hil_server': module}), \
                patch.object(unified, 'preflight', side_effect=lambda: events.append('preflight') or {}), \
                patch.object(unified, 'program', side_effect=lambda p: events.append('load')), \
                patch.object(unified, 'serve', side_effect=serve):
            unified.approved_action('run', True, {'base': 0xa1000000}, '', 0)
        self.assertEqual(events, ['preflight', 'load', 'open-ahil', 'serve-with-camera'])
        device.stop.assert_called_once()
        device.close.assert_called_once()

    def test_packaging_rejects_failed_or_unconstrained_implementation(self):
        timing = ('Tool Version : Vivado v.2020.2\nDesign : design_1_wrapper\n'
                  'All user specified timing constraints are met.\n'
                  'clk_pl_0 {0.000 2.491} 4.982 200.704\n'
                  'clk_pl_1 {0.000 4.982} 9.965 100.352\n')
        checks = ['no_clock', 'unconstrained_internal_endpoints', 'no_input_delay',
                  'no_output_delay', 'multiple_clock', 'generated_clocks', 'loops',
                  'partial_input_delay', 'partial_output_delay', 'latch_loops']
        timing += ''.join('checking %s (0)\n' % name for name in checks)
        drc = 'Tool Version : Vivado v.2020.2\nDesign : design_1_wrapper\nViolations found: 0\n'
        with tempfile.TemporaryDirectory() as directory:
            build = Path(directory)
            (build / 'drc_impl.rpt').write_text(drc)
            (build / 'timing_impl.rpt').write_text(timing)
            check_reports(build)
            for invalid in [timing.replace('are met.', 'are not met.'),
                            timing.replace('4.982 200.704', '5.000 200.000'),
                            timing.replace('unconstrained_internal_endpoints (0)',
                                           'unconstrained_internal_endpoints (4)'),
                            timing.replace('no_input_delay (0)', 'no_input_delay (2)'),
                            timing.replace('v.2020.2', 'v.2020.1')]:
                with self.subTest(report=invalid):
                    (build / 'timing_impl.rpt').write_text(invalid)
                    with self.assertRaises(ValueError):
                        check_reports(build)
            (build / 'timing_impl.rpt').write_text(timing)
            (build / 'drc_impl.rpt').write_text(drc.replace('found: 0', 'found: 1'))
            with self.assertRaisesRegex(ValueError, 'DRC'):
                check_reports(build)


if __name__ == '__main__':
    unittest.main()
