import json, os, signal, socket, sys, time
from pathlib import Path
package=Path('/run/amazinghand-hil-20261017-v2')
sys.path.insert(0,str(package))
from hil_server import PlDevice, PROTOCOL
from linux_hil import server_pid, verified_manifest
manifest=verified_manifest()
pid=server_pid()
assert pid
samples=[]
paused=False
device=None
with socket.create_connection(('192.28.14.153',8765),timeout=2) as conn:
    with conn.makefile('rwb') as stream:
        def exchange(frame):
            stream.write((json.dumps(frame)+'\n').encode());stream.flush()
            return json.loads(stream.readline(4097))
        hello=exchange(dict(protocol=PROTOCOL,cmd='hello'))
        seq=hello['accepted_seq']
        replies=[]
        for cmd in ['reset','open']:
            seq+=1
            replies.append(exchange(dict(protocol=PROTOCOL,seq=seq,heartbeat=seq,cmd=cmd,
                target_raw=[2048]*8,feedback=dict(position_raw=[2048]*8,load_raw=[0]*8,online_mask=255))))
        assert replies[-1]['torque_enabled'] and replies[-1]['fault']==0,replies[-1]
        try:
            os.kill(pid,signal.SIGSTOP);paused=True
            device=PlDevice(manifest['base'])
            start=time.monotonic()
            for deadline in [0.10,0.48,0.54,0.65]:
                time.sleep(max(0,deadline-(time.monotonic()-start)))
                samples.append(dict(elapsed_s=time.monotonic()-start,pl=device.snapshot()))
            assert samples[0]['pl']['torque_enabled'] and samples[1]['pl']['torque_enabled']
            assert not samples[2]['pl']['torque_enabled'] and samples[2]['pl']['fault'] & 1
            assert samples[2]['pl']['state']=='PROTECT'
            assert all(x['pl']['accepted_seq']==seq and x['pl']['feedback_seq']==seq for x in samples)
            print(json.dumps(dict(result='PASS',method='SIGSTOP real PS bridge; read real PL snapshot without COMMIT',
                feedback_profile='fixed valid synthetic feedback for watchdog only; GUI check separately uses MuJoCo',
                clock_hz=manifest['clock_hz'],service_pid=pid,last_reply=replies[-1],samples=samples),indent=2))
        finally:
            if device is not None:device.close()
            if paused:os.kill(pid,signal.SIGCONT)
