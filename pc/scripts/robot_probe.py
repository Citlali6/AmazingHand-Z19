"""Safe default mock probe. Real mode is explicit and QUERY-ONLY."""
from __future__ import annotations

import argparse
from dataclasses import asdict
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from visiongrasp.contracts import ActionRequest, MOTION_STAGES
from visiongrasp.robot import FakeRobot, RoArmSerialRobot


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("mock", "real"), default="mock")
    parser.add_argument("--dry-run", action="store_true", help="explicit mock-only assertion")
    parser.add_argument("--port")
    parser.add_argument("--onsite-confirmed", action="store_true")
    parser.add_argument("--confirm-query-only", action="store_true")
    parser.add_argument("--log", type=Path, default=Path(__file__).resolve().parents[2] / "output/pc/issue7/robot_probe.jsonl")
    args = parser.parse_args(argv)
    if args.mode == "real" and (args.dry_run or not args.port or not args.onsite_confirmed or not args.confirm_query_only):
        parser.error("real QUERY requires --port, --onsite-confirmed, --confirm-query-only and no --dry-run")
    robot = FakeRobot() if args.mode == "mock" else RoArmSerialRobot(mode="real", port=args.port, onsite_confirmed=True)
    records = [{"robot_source": robot.robot_source.value, "sdk_available": importlib.util.find_spec("roarm_sdk") is not None,
                "hardware_status": "ROARM NOT TESTED" if args.mode == "mock" else "ON-SITE QUERY ONLY"}]
    exit_code = 0
    try:
        if args.mode == "real":
            robot.connect()
        feedback = robot.query_feedback()
        records.append(asdict(feedback))
        if not feedback.communication_ok:
            exit_code = 1
        elif args.mode == "mock":
            session = uuid.uuid4().hex
            robot.begin_run(session)
            for sequence, stage in enumerate(MOTION_STAGES):
                result = robot.send_stage(ActionRequest(session, sequence, stage, operator_confirmed=True,
                                                        calibration_id="synthetic-table-probe"))
                records.append(asdict(result))
    except Exception:
        records.append({"error": "QUERY_CONNECTION_FAILED", "robot_source": robot.robot_source.value})
        exit_code = 1
    finally:
        robot.close()
    args.log.parent.mkdir(parents=True, exist_ok=True)
    with args.log.open("a", encoding="utf-8") as stream:
        for record in records:
            record["wall_time_utc"] = datetime.now(timezone.utc).isoformat()
            line = json.dumps(record, ensure_ascii=False)
            print(line)
            stream.write(line + "\n")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
