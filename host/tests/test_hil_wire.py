"""Wire validation only; these tests are not evidence of PL hardware operation."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.control.backend_hil import validate_reply


class WireTests(unittest.TestCase):
    def reply(self):
        return dict(protocol="amazinghand-hil/1", source="pl", seq=4,
                    accepted_seq=4, feedback_seq=4, fault=0, pl_tick=10,
                    command_count=2, feedback_count=4, state="HOLD",
                    torque_enabled=True, target_raw=[2048] * 8)

    def test_valid_ack(self):
        self.assertEqual(validate_reply(self.reply(), 4)["state"], "HOLD")

    def test_reject_wrong_source_old_ack_and_missing_counter(self):
        for field, value in (("source", "sim"), ("accepted_seq", 3),
                             ("feedback_seq", 3), ("command_count", None)):
            with self.subTest(field=field):
                reply = self.reply()
                reply[field] = value
                with self.assertRaises(ValueError):
                    validate_reply(reply, 4)

    def test_reject_unsafe_fault_telemetry(self):
        reply = self.reply()
        reply["fault"] = 1
        with self.assertRaisesRegex(ValueError, "unsafe"):
            validate_reply(reply, 4)

    def test_reject_bad_targets(self):
        for targets in ([2048] * 7, [True] * 8, [4096] * 8):
            reply = self.reply()
            reply["target_raw"] = targets
            with self.assertRaises(ValueError):
                validate_reply(reply, 4)


if __name__ == "__main__":
    unittest.main(verbosity=2)
