"""Start/stop only this deployment's inference service; never touches PL/camera."""
import argparse
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('start','stop','status'))
    parser.add_argument('--state-dir', type=Path, default=Path('/run/amazinghand-vision'))
    parser.add_argument('--log-dir', type=Path, default=Path('/var/lib/amazinghand/log'))
    args, service_args = parser.parse_known_args()
    service = Path(__file__).with_name('live_vision.py').resolve()
    args.state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    pid_file = args.state_dir / 'service.json'
    active = None
    if pid_file.exists():
        active = json.loads(pid_file.read_text())
        proc = Path('/proc/%d' % active['pid'])
        if not proc.exists():
            active = None
        else:
            argv = (proc / 'cmdline').read_bytes().split(b'\0')
            start = (proc / 'stat').read_text().split(') ',1)[1].split()[19]
            if str(service).encode() not in argv or active['start_ticks'] != start:
                raise RuntimeError('PID identity changed; refusing to signal another process')
    if args.action == 'status':
        print(json.dumps(active or {'state':'STOPPED'}))
    elif args.action == 'stop':
        if active:
            os.kill(active['pid'], signal.SIGTERM)
        print('VISION_STOP_REQUESTED' if active else 'VISION_ALREADY_STOPPED')
    else:
        if active:
            raise RuntimeError('vision service already running')
        stamp = datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
        args.log_dir.mkdir(mode=0o700,parents=True,exist_ok=True)
        logfile = args.log_dir / ('vision-' + stamp + '.jsonl')
        with logfile.open('xb') as output:
            proc = subprocess.Popen([sys.executable,str(service)] + service_args,
                                    stdin=subprocess.DEVNULL, stdout=output,stderr=subprocess.STDOUT,
                                    start_new_session=True,close_fds=True)
        start = Path('/proc/%d/stat' % proc.pid).read_text().split(') ',1)[1].split()[19]
        state = dict(pid=proc.pid,start_ticks=start,log=str(logfile),service=str(service))
        pid_file.write_text(json.dumps(state))
        print(json.dumps(state))


if __name__ == '__main__':
    main()
