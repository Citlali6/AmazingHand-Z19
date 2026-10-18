"""Read-only same-frame evidence collector. Runs on a PC; performs no inference."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import statistics
import time
from urllib.request import ProxyHandler, build_opener


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url',default='http://127.0.0.1:8768')
    parser.add_argument('--seconds',type=float,default=30)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--camera-url',help='optional existing preview service for concurrent FPS')
    args=parser.parse_args()
    if args.output.exists(): parser.error('output must be a new directory')
    args.output.mkdir(parents=True)
    opener=build_opener(ProxyHandler({}))
    started=time.monotonic()
    results,seen,states=[],set(),{}
    first=None
    camera_rows,last_camera=[],0.
    with (args.output/'samples.jsonl').open('x') as log:
        while time.monotonic()-started<args.seconds:
            try:
                if args.camera_url and time.monotonic()-last_camera>=1:
                    with opener.open(args.camera_url.rstrip('/')+'/status.json',timeout=3) as response:
                        camera_rows.append(json.load(response))
                    last_camera=time.monotonic()
                with opener.open(args.url.rstrip('/')+'/result.json',timeout=3) as response:
                    value=json.load(response)
                states[value['state']]=states.get(value['state'],0)+1
                image=value.pop('jpeg_base64',None)
                log.write(json.dumps(value)+'\n')
                if image:
                    assert value['architecture']=='aarch64', 'not ARM64 board result'
                    assert value['autonomous_grasp_allowed'] is False
                    jpeg=base64.b64decode(image,validate=True)
                    assert hashlib.sha256(jpeg).hexdigest()==value['jpeg_sha256'], 'wrong JPEG/result association'
                    identity=(value['camera_session'],value['frame_seq'])
                    if identity not in seen:
                        seen.add(identity)
                        results.append(value)
                        if first is None and value['detections']:
                            first=value
                            (args.output/'same-frame.jpg').write_bytes(jpeg)
                            (args.output/'same-frame.json').write_text(json.dumps(value,indent=2)+'\n')
            except Exception as error:
                key='COLLECTOR_ERROR: '+str(error)
                states[key]=states.get(key,0)+1
            time.sleep(.2)
    duration=time.monotonic()-started
    summary=dict(duration_seconds=duration, unique_published_results=len(results),
                 observed_result_fps=len(results)/duration,states=states,
                 note='PC HTTP observer; inference performed by the reported ARM64 process',
                 first_detection_result=first)
    if results:
        for key in ('inference_ms','native_inference_ms','age_ms','service_and_bridge_rss_kib'):
            values=sorted(row[key] for row in results)
            summary[key]=dict(median=statistics.median(values),min=min(values),max=max(values),
                              p95=values[min(len(values)-1,int(.95*len(values)))])
        if len(results)>1:
            summary['cpu_percent_one_core_service_and_bridge']=(
                results[-1]['service_and_bridge_cpu_seconds']-results[0]['service_and_bridge_cpu_seconds'])/duration*100
    if camera_rows:
        fps=[row['preview_fps'] for row in camera_rows if row.get('state')=='LIVE']
        summary['camera_states']={state:sum(row.get('state')==state for row in camera_rows)
                                  for state in set(row.get('state') for row in camera_rows)}
        if fps: summary['concurrent_camera_fps']=dict(median=statistics.median(fps),min=min(fps),max=max(fps))
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
    return 0 if first else 1


if __name__=='__main__': raise SystemExit(main())
