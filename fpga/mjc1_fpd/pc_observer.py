"""Visible MuJoCo observer: accepts real PL targets only; never generates input."""
import json
from pathlib import Path
import socket
import sys
import time

BRIDGE_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BRIDGE_ROOT))
import mujoco
import mujoco.viewer
from sim.mujoco_observer import Observer, STATES


def overlay(viewer, caption, detail):
    viewer.set_texts((mujoco.mjtFontScale.mjFONTSCALE_150,
                      mujoco.mjtGridPos.mjGRID_TOPLEFT, caption, detail))


def main():
    trace_dir = Path(__file__).with_name('out')
    trace_dir.mkdir(parents=True, exist_ok=True)
    observer = Observer(trace_dir / 'pl_trace.jsonl', 32.0)
    with mujoco.viewer.launch_passive(observer.model, observer.data,
                                     show_left_ui=False, show_right_ui=False) as viewer:
        with viewer.lock():
            viewer.cam.lookat[:] = [.025, 0, .085]
            viewer.cam.distance = .42
            viewer.cam.azimuth = 150
            viewer.cam.elevation = -22
        overlay(viewer, 'Z19 / MJC1 PL control', 'WAITING FOR BOARD - no software input')
        viewer.sync()
        with socket.socket() as server:
            server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server.bind(('127.0.0.1', 8765))
            server.listen(1)
            server.settimeout(.3)
            print('PL_OBSERVER_READY 127.0.0.1:8765', flush=True)
            while viewer.is_running():
                try:
                    connection, address = server.accept()
                except socket.timeout:
                    viewer.sync()
                    continue
                print('BOARD_TRANSPORT_CONNECTED %s' % (address,), flush=True)
                connection.settimeout(2)
                previous = 0
                try:
                    with connection:
                        wire = connection.makefile('rwb', buffering=0)
                        while viewer.is_running():
                            line = wire.readline(65537)
                            if not line:
                                break
                            if len(line) > 65536 or not line.endswith(b'\n'):
                                raise ValueError('oversized/incomplete frame')
                            message = json.loads(line)
                            if type(message.get('seq')) is not int or message['seq'] <= previous:
                                raise ValueError('stale board sequence')
                            previous = message['seq']
                            state = STATES.get(message.get('state'), 'INVALID')
                            overlay(viewer, 'Z19 / MJC1 PL control\nActual FPGA state\nFeedback sequence\nControl path',
                                    'LIVE\n%s\n%d\nPL -> PS -> TCP -> MuJoCo -> PL' % (state, previous))
                            reply = observer.consume(message, viewer)
                            wire.write((json.dumps(reply, separators=(',', ':')) + '\n').encode())
                except (OSError, ValueError) as error:
                    print('BOARD_SESSION_ENDED %s' % error, flush=True)
                overlay(viewer, 'Z19 / MJC1 PL control', 'BOARD DISCONNECTED - last pose retained')
                viewer.sync()
    observer.close()


if __name__ == '__main__':
    main()
