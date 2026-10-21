import json
from pathlib import Path
import subprocess
import sys

import pytest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "pc/scripts/robot_probe.py"


def test_probe_default_mock_seven_stages(tmp_path):
    destination = tmp_path / "probe.jsonl"
    result = subprocess.run([sys.executable, str(SCRIPT), "--log", str(destination)],
                            cwd=ROOT, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stderr
    records = [json.loads(line) for line in destination.read_text(encoding="utf-8").splitlines()]
    assert records[0]["hardware_status"] == "ROARM NOT TESTED"
    assert records[0]["robot_source"] == "FAKE"
    assert records[1]["end_xyz_mm"] is None
    assert len([r for r in records if r.get("status") == "DRY_RUN"]) == 7
    assert all("wall_time_utc" in r for r in records)


@pytest.mark.parametrize("flags", [
    ["--mode", "real"],
    ["--mode", "real", "--port", "DO-NOT-OPEN", "--onsite-confirmed"],
    ["--mode", "real", "--port", "DO-NOT-OPEN", "--onsite-confirmed", "--confirm-query-only", "--dry-run"],
])
def test_real_cli_missing_gates_rejected_before_any_import_or_connection(flags, tmp_path):
    result = subprocess.run([sys.executable, str(SCRIPT), *flags, "--log", str(tmp_path / "never.jsonl")],
                            cwd=ROOT, capture_output=True, text=True, timeout=10)
    assert result.returncode == 2
    assert "real QUERY requires" in result.stderr
    assert not (tmp_path / "never.jsonl").exists()


def test_fake_import_does_not_load_sdk_or_serial_in_fresh_process():
    command = "import sys; sys.path.insert(0, 'pc'); from visiongrasp.robot import FakeRobot; r=FakeRobot(); r.query_feedback(); r.close(); assert 'roarm_sdk' not in sys.modules; assert 'serial' not in sys.modules"
    result = subprocess.run([sys.executable, "-c", command], cwd=ROOT,
                            capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stderr
