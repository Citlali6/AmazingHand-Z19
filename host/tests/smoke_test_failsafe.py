"""Issue #6: PC fault injection; no serial device or FPGA access.

Run: python host/tests/smoke_test_failsafe.py
"""

from __future__ import annotations

from contextlib import redirect_stderr
import io
import signal
import sys
from pathlib import Path
import types
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import main as app
from app.control.backend_fpga import AxilRegs, FpgaBackend
from app.control.backend_serial import SerialBackend
from app.control.backend_sim import SimBackend
from app.strategy.grasp_selector import GraspSelector


class TrackingBackend(SimBackend):
    def __init__(self, failures=None):
        super().__init__()
        self.events = []
        self.failures = failures or {}

    def _event(self, name):
        self.events.append(name)
        if name in self.failures:
            raise self.failures[name]

    def open(self):
        super().open()
        self.bus.inject_external_load({sid: 500 for sid in self.bus.servo_ids})
        self._event("open")

    def emergency_stop(self):
        super().emergency_stop()
        self._event("stop")

    def close(self):
        super().close()
        self._event("close")


def deps_for(backend):
    return app.Deps(
        backend=backend,
        voice=app.MockVoice([app.Command("grasp", "banana"), app.Command("release")], 0),
        vision=app.MockVision(delay_ticks=0),
        selector=GraspSelector(),
        log=lambda _: None,
    )


class FailsafeTests(unittest.TestCase):
    def assert_torque_off(self, backend):
        self.assertTrue(all(not backend.bus.state(sid).torque_on
                            for sid in backend.bus.servo_ids))

    def test_pipeline_exceptions_stop_and_close_preserving_original(self):
        # Exercise each external callback at the point where the real loop uses it.
        for owner, method in (
            ("backend", "tick"), ("voice", "poll_command"),
            ("vision", "detect_target"), ("vision", "guide_hand"),
            ("selector", "select"), ("backend", "start_grasp_fsm"),
            ("backend", "poll_fsm"), ("backend", "release"),
        ):
            with self.subTest(owner=owner, method=method):
                backend = TrackingBackend()
                deps = deps_for(backend)
                original = OSError(f"injected {method}")
                with patch.object(getattr(deps, owner), method, side_effect=original):
                    with self.assertRaises(OSError) as caught:
                        with backend:
                            app.run(deps, max_ticks=1000)
                self.assertIs(caught.exception, original)
                self.assertEqual(backend.events, ["open", "stop", "close"])
                self.assert_torque_off(backend)

    def test_normal_loop_completion_stops_and_closes(self):
        backend = TrackingBackend()
        with backend:
            history = app.run(deps_for(backend), max_ticks=1000)
        self.assertTrue(any(s.startswith("RELEASING") for s in history))
        self.assertEqual(backend.events, ["open", "stop", "close"])
        self.assert_torque_off(backend)

    def test_tick_budget_ends_during_grasp_with_torque_off(self):
        backend = TrackingBackend()
        with backend:
            history = app.run(deps_for(backend), max_ticks=3)
            self.assertTrue(history[-1].startswith("GRASPING"))
        self.assert_torque_off(backend)

    def test_partial_open_failure_closes_without_entering_body(self):
        original = OSError("partial open")
        backend = TrackingBackend({"open": original})
        with self.assertRaises(OSError) as caught:
            with backend:
                self.fail("body must not run")
        self.assertIs(caught.exception, original)
        self.assertEqual(backend.events, ["open", "close"])

    def test_open_cleanup_failure_does_not_mask_original(self):
        original = OSError("partial open")
        backend = TrackingBackend({"open": original, "close": RuntimeError("close")})
        with self.assertLogs("app.control.servo_base", level="ERROR"):
            with self.assertRaises(OSError) as caught:
                with backend:
                    self.fail("body must not run")
        self.assertIs(caught.exception, original)

    def test_stop_and_close_failure_preserve_application_error(self):
        backend = TrackingBackend({"stop": OSError("stop"), "close": OSError("close")})
        original = ValueError("vision failed")
        with self.assertLogs("app.control.servo_base", level="ERROR") as logs:
            with self.assertRaises(ValueError) as caught:
                with backend:
                    raise original
        self.assertIs(caught.exception, original)
        self.assertEqual(backend.events, ["open", "stop", "close"])
        self.assertEqual(len(logs.records), 2)

    def test_shutdown_failure_is_not_reported_as_success(self):
        for name in ("stop", "close"):
            with self.subTest(name=name):
                backend = TrackingBackend({name: OSError(name)})
                with self.assertLogs("app.control.servo_base", level="ERROR"):
                    with self.assertRaisesRegex(RuntimeError, "stop is unconfirmed"):
                        with backend:
                            pass
                self.assertEqual(backend.events, ["open", "stop", "close"])

    def test_cli_runtime_failure_returns_one_after_cleanup(self):
        backend = TrackingBackend()
        with patch.object(app, "build_backend", return_value=backend), \
                patch.object(app, "run", side_effect=OSError("camera failed")), \
                redirect_stderr(io.StringIO()) as output:
            self.assertEqual(app.main(["--mock-voice", ""]), 1)
        self.assertIn("camera failed", output.getvalue())
        self.assertEqual(backend.events, ["open", "stop", "close"])

    def test_cli_interrupt_returns_130_after_cleanup(self):
        backend = TrackingBackend()
        with patch.object(app, "build_backend", return_value=backend), \
                patch.object(app, "run", side_effect=KeyboardInterrupt), \
                redirect_stderr(io.StringIO()):
            self.assertEqual(app.main(["--mock-voice", ""]), 130)
        self.assertEqual(backend.events, ["open", "stop", "close"])

    def test_signal_handlers_unwind_and_restore(self):
        for signum, error_type, code in (
            (signal.SIGINT, KeyboardInterrupt, None),
            (signal.SIGTERM, SystemExit, 143),
        ):
            with self.subTest(signum=signum):
                previous = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM)}
                backend = TrackingBackend()
                with self.assertRaises(error_type) as caught:
                    with app.shutdown_signals():
                        with backend:
                            # Invoke installed handler portably (Windows SIGTERM kills).
                            signal.getsignal(signum)(signum, None)
                if code is not None:
                    self.assertEqual(caught.exception.code, code)
                for s, handler in previous.items():
                    self.assertEqual(signal.getsignal(s), handler)
                self.assertEqual(backend.events, ["open", "stop", "close"])

    def test_repeated_signals_cannot_interrupt_shutdown(self):
        with app.shutdown_signals():
            with self.assertRaises(KeyboardInterrupt):
                signal.getsignal(signal.SIGINT)(signal.SIGINT, None)
            self.assertEqual(signal.getsignal(signal.SIGINT), signal.SIG_IGN)
            self.assertEqual(signal.getsignal(signal.SIGTERM), signal.SIG_IGN)

    def test_signal_during_normal_shutdown_still_closes_and_keeps_exit_code(self):
        for signum, error_type in ((signal.SIGINT, KeyboardInterrupt),
                                   (signal.SIGTERM, SystemExit)):
            with self.subTest(signum=signum):
                backend = TrackingBackend()

                def interrupted_stop():
                    backend.events.append("stop")
                    signal.getsignal(signum)(signum, None)

                with app.shutdown_signals(), \
                        patch.object(backend, "emergency_stop", side_effect=interrupted_stop), \
                        self.assertLogs("app.control.servo_base", level="ERROR"):
                    with self.assertRaises(error_type) as caught:
                        with backend:
                            pass
                if signum == signal.SIGTERM:
                    self.assertEqual(caught.exception.code, 143)
                self.assertEqual(backend.events, ["open", "stop", "close"])
                self.assert_torque_off(backend)


class ResourceTests(unittest.TestCase):
    def test_serial_writes_have_timeout_and_close_is_idempotent(self):
        serial_port = Mock()
        factory = Mock(return_value=serial_port)
        with patch.dict(sys.modules, {"serial": types.SimpleNamespace(Serial=factory)}):
            backend = SerialBackend(timeout_s=0.02)
            backend.open()
        self.assertEqual(factory.call_args.kwargs["write_timeout"], 0.02)
        serial_port.write.side_effect = OSError("disconnected")
        with self.assertRaisesRegex(OSError, "disconnected"):
            backend.close()
        serial_port.close.assert_called_once()
        self.assertIsNone(backend._ser)
        backend.close()
        serial_port.close.assert_called_once()

    def test_serial_close_failure_does_not_retain_stale_handle(self):
        backend = SerialBackend()
        backend._ser = Mock()
        backend._ser.close.side_effect = OSError("close failed")
        with patch.object(backend, "set_torque"):
            with self.assertRaises(OSError):
                backend.close()
        self.assertIsNone(backend._ser)

    def test_mmap_failure_releases_fd(self):
        regs = AxilRegs()
        original = OSError("mmap failed")
        with patch("os.open", return_value=123), patch("os.close") as close_fd, \
                patch("os.O_SYNC", 0, create=True), \
                patch.multiple("mmap", MAP_SHARED=1, PROT_READ=1, PROT_WRITE=2, create=True), \
                patch("mmap.mmap", side_effect=original):
            with self.assertRaises(OSError) as caught:
                regs.open()
            regs.close()
        self.assertIs(caught.exception, original)
        close_fd.assert_called_once_with(123)
        self.assertIsNone(regs._fd)
        self.assertIsNone(regs._map)

    def test_mapping_close_failure_still_releases_fd(self):
        regs = AxilRegs()
        regs._map = Mock()
        regs._map.close.side_effect = OSError("unmap failed")
        regs._fd = 123
        with patch("os.close") as close_fd:
            with self.assertRaisesRegex(OSError, "unmap failed"):
                regs.close()
            regs.close()
        close_fd.assert_called_once_with(123)

    def test_fpga_stop_failure_still_releases_registers(self):
        backend = FpgaBackend()
        backend._regs = Mock()
        backend.open()
        with patch.object(backend, "emergency_stop", side_effect=OSError("AXI failed")) as stop:
            with self.assertRaisesRegex(OSError, "AXI failed"):
                backend.close()
            backend.close()
        stop.assert_called_once()
        self.assertEqual(backend._regs.close.call_count, 2)
        self.assertFalse(backend._opened)

    def test_fpga_initial_configuration_failure_releases_registers(self):
        backend = FpgaBackend()
        backend._regs = Mock()
        original = OSError("AXI init failed")
        backend._regs.write32.side_effect = original
        with patch.object(backend, "emergency_stop"):
            with self.assertRaises(OSError) as caught:
                with backend:
                    self.fail("body must not run")
        self.assertIs(caught.exception, original)
        backend._regs.close.assert_called_once()


if __name__ == "__main__":
    unittest.main(verbosity=2)
