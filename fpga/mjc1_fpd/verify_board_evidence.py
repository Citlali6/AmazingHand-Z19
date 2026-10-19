"""Check saved real-board acknowledgements against the live MuJoCo trace."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parent
out = root / 'out'
frames = []
previous = 0
for line in (out / 'pl_trace.jsonl').read_text().splitlines():
    if not line.strip():
        continue
    frame = json.loads(line)
    if frame['seq'] <= previous:
        frames = []  # A new real board transport session resets its counter.
    previous = frame['seq']
    frames.append(frame)
assert len(frames) > 500
assert all(len(f['target_raw']) == len(f['position_raw']) == 8 for f in frames)
sequences = {f['seq'] for f in frames}
board = (out / 'board_native32_capture.txt').read_text(errors='replace')
acknowledgements = [int(x) for x in re.findall(r'(?:accepted_seq|PL_FEEDBACK_ACK seq)=(\d+)', board)]
cycles = [int(x) for x in re.findall(r'PL_CYCLE_COMPLETE cycle=(\d+)', board)]
assert acknowledgements and cycles and max(cycles) >= 2
assert all((ack - 1) in sequences for ack in acknowledgements)
transitions = []
for frame in frames:
    if not transitions or transitions[-1] != frame['state']:
        transitions.append(frame['state'])
expected = ['PREGRASP', 'CLOSING', 'HOLD', 'RELEASING', 'IDLE']
assert any(transitions[i:i+5] == expected for i in range(len(transitions)-4))
travel = max(f['position_raw'][0] for f in frames) - min(f['position_raw'][0] for f in frames)
assert travel >= 400
result = {
    'passed': True,
    'date': '2026-10-18',
    'source': 'Real Z19 MJC1 PL targets; native 32-bit PS MMIO; MuJoCo feedback',
    'base': '0xa0000000',
    'pl_version': '1.1 / reset-fixed R2',
    'pc_frames_in_current_session': len(frames),
    'confirmed_completed_board_cycles_at_least': max(cycles),
    'last_captured_board_accepted_sequence': max(acknowledgements),
    'all_captured_acknowledgements_match_pc_feedback': True,
    'first_joint_travel_raw': travel,
    'first_joint_travel_degrees': travel / 10,
    'state_transitions': transitions,
    'hold_limit': 'Observed HOLD status 0x23: closing timer, not calibrated contact-force acceptance',
    'camera': 'Stopped and driver unloaded before loading the virtual-only PL image',
}
with (out / 'board_validation.json').open('x', encoding='utf-8') as report:
    json.dump(result, report, ensure_ascii=False, indent=2)
print(json.dumps({k:v for k,v in result.items() if k != 'state_transitions'}, ensure_ascii=False))
