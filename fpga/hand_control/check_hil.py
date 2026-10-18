#!/usr/bin/env python3
"""Run the existing Issue #10 app against a real board, preserving both trees.

No PL emulation or software fallback. The app receives live HTTP operator
commands while MuJoCo exchanges feedback with the board's HIL service.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host-tree', type=Path, required=True)
    parser.add_argument('--address', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--gui', action='store_true')
    parser.add_argument('--port', type=int, default=8767)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('output must be a new directory')
    args.output.mkdir(parents=True)
    base = 'http://127.0.0.1:%d' % args.port
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    samples = []
    def request(path, data=None):
        body = None if data is None else json.dumps(data).encode()
        req = urllib.request.Request(base + path, data=body,
                                     headers={'Content-Type': 'application/json'})
        with opener.open(req, timeout=2) as response:
            return json.load(response)
    def observe(seconds):
        until = time.monotonic() + seconds
        while time.monotonic() < until:
            state = request('/state')
            assert state['source'] == 'pl' and state['pl']['source'] == 'pl'
            assert state['pl']['accepted_seq'] == state['pl']['feedback_seq']
            samples.append(state)
            time.sleep(0.05)
        return samples[-1]
    def action(name, duration):
        request('/command', {'action': name, 'category': 'banana'})
        result = observe(duration)
        assert result['events'][-1]['action'] == name
        assert result['events'][-1]['accepted'], result['message']
        return result
    head = subprocess.check_output(['git', '-C', str(args.host_tree), 'rev-parse', 'HEAD'], text=True).strip()
    command = [sys.executable, str(args.host_tree / 'host/app/main.py'), '--mujoco',
               '--hil', args.address, '--port', str(args.port), '--duration', '14']
    command += ['--snapshot', str(args.output / 'hil-panel.png')] if args.gui else ['--headless']
    with (args.output / 'app.txt').open('w') as log:
        proc = subprocess.Popen(command, cwd=str(args.host_tree), stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(100):
                assert proc.poll() is None, 'app exited; inspect app.txt'
                try:
                    if request('/state').get('source') == 'pl':
                        break
                    time.sleep(0.1)
                except (OSError, ValueError, urllib.error.URLError):
                    time.sleep(0.1)
            else:
                raise RuntimeError('app API not ready')
            initial = observe(0.2)
            assert initial['stopped'] and not initial['torque_enabled']
            action('reset', 0.2)
            opened = action('open', 0.4)
            grasped = action('grasp', 1.2)
            held = action('hold', 0.4)
            assert held['state'] == 'HOLD'
            released = action('release', 0.8)
            assert released['state'] == 'IDLE'
            stopped = action('stop', 0.3)
            assert stopped['stopped'] and not stopped['torque_enabled']
            assert max(abs(v) for v in stopped['actuator_force']) == 0
            request('/command', {'action': 'grasp'})
            rejected = observe(0.3)
            assert not rejected['events'][-1]['accepted']
            assert rejected['positions_deg'] == stopped['positions_deg']
            action('reset', 0.2)
            reset = samples[-1]
            assert not reset['torque_enabled']
            action('grasp', 0.8)
            action('stop', 0.3)
            movement = max(abs(a-b) for a,b in zip(grasped['positions_deg'], opened['positions_deg']))
            assert movement > 1, 'real MuJoCo joints did not move'
            assert grasped['pl']['feedback_count'] > opened['pl']['feedback_count']
            assert grasped['pl']['command_count'] > opened['pl']['command_count']
            assert grasped['pl']['position_raw'] != opened['pl']['position_raw']
            result = dict(result='PASS', client_head=head, board=args.address, gui=args.gui,
                          max_joint_change_deg=movement, samples=len(samples),
                          initial=initial['pl'], final=samples[-1]['pl'],
                          checks=['open/grasp/hold/release', 'PL ACK and feedback counters',
                                  'MuJoCo movement and feedback changes', 'STOP zero force and frozen pose',
                                  'latched STOP rejects motion', 'reset keeps torque off until new motion'])
            assert proc.wait(timeout=20) == 0, 'app failed during cleanup'
            (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps(result, indent=2))
        finally:
            (args.output / 'samples.json').write_text(json.dumps(samples, indent=2) + '\n')
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=5)


if __name__ == '__main__':
    main()
