"""Read-only on-board profiling of the existing camera and optional AI service.

No model imports, control commands, package installs or FPGA operations. JSONL
contains timings/identities only; source JPEGs remain outside this collector.
"""
import argparse
import json
import os
from pathlib import Path
import statistics
import time
from urllib.request import ProxyHandler, build_opener


def stat_cpu():
    result={}
    for line in Path('/proc/stat').read_text().splitlines():
        fields=line.split()
        if fields and fields[0].startswith('cpu'):
            values=[int(x) for x in fields[1:9]]
            result[fields[0]]=(sum(values),values[3]+values[4])
    return result


def processes(pids):
    result={}
    for label,pid in pids.items():
        try:
            fields=Path('/proc/%d/stat'%pid).read_text().split(') ',1)[1].split()
            rss=next(int(x.split()[1]) for x in Path('/proc/%d/status'%pid).read_text().splitlines() if x.startswith('VmRSS:'))
            result[label]=dict(pid=pid,cpu_ticks=int(fields[11])+int(fields[12]),rss_kib=rss)
        except (OSError,StopIteration): pass
    return result


def distribution(values):
    values=sorted(values)
    return dict(median=statistics.median(values),p95=values[min(len(values)-1,int(.95*len(values)))],
                min=min(values),max=max(values)) if values else None


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--seconds',type=float,default=30)
    parser.add_argument('--camera-url',default='http://127.0.0.1:9000')
    parser.add_argument('--vision-url')
    parser.add_argument('--preview-pid',type=int,required=True)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    opener=build_opener(ProxyHandler({}))
    def get(url):
        with opener.open(url,timeout=3) as response: return json.load(response)
    pids={'preview':args.preview_pid}
    children=Path('/proc/%d/task/%d/children'%(args.preview_pid,args.preview_pid)).read_text().split()
    if children: pids['capture']=int(children[0])
    began=time.monotonic()
    previous=stat_cpu()
    samples,unique=[],{}
    with (args.output/'samples.jsonl').open('x') as output:
        while time.monotonic()-began<args.seconds:
            stamp=time.monotonic()
            sample=dict(elapsed_s=stamp-began)
            try:
                sample['camera']=get(args.camera_url.rstrip('/')+'/status.json')
                if args.vision_url:
                    vision=get(args.vision_url.rstrip('/')+'/result.json')
                    vision.pop('jpeg_base64',None)
                    sample['vision']=vision
                    for key,label in [('pid','vision'),('bridge_pid','native')]:
                        if key in vision: pids[label]=vision[key]
                    if ('frame_seq' in vision and 'camera_session' in vision
                            and vision.get('state') in ('LIVE','NO_TARGET')):
                        unique[(vision['camera_session'],vision['frame_seq'])]=vision
            except Exception as error: sample['error']=str(error)
            current=stat_cpu()
            sample['cpu_percent']={core:100*(1-(idle-previous[core][1])/(total-previous[core][0]))
                                   for core,(total,idle) in current.items()
                                   if core in previous and total>previous[core][0] and stamp-began>.2}
            previous=current
            sample['processes']=processes(pids)
            samples.append(sample)
            output.write(json.dumps(sample)+'\n'); output.flush()
            time.sleep(.5)
    duration=time.monotonic()-began
    summary=dict(duration_s=duration,samples=len(samples),
                 preview_fps=distribution([s['camera']['preview_fps'] for s in samples if s.get('camera',{}).get('state')=='LIVE']),
                 camera_copy_ms=distribution([s['camera']['copy_ms'] for s in samples if 'copy_ms' in s.get('camera',{})]),
                 camera_encode_ms=distribution([s['camera']['encode_ms'] for s in samples if 'encode_ms' in s.get('camera',{})]),
                 per_core_cpu_percent={core:distribution([s['cpu_percent'][core] for s in samples if core in s['cpu_percent']]) for core in previous},
                 rss_kib={label:distribution([s['processes'][label]['rss_kib'] for s in samples if label in s['processes']]) for label in pids},
                 errors=[s['error'] for s in samples if 'error' in s])
    # Linux process CPU is percent of one core; /proc/stat cpu is total capacity.
    summary['process_cpu_percent']={}
    for label in pids:
        readings=[(s['elapsed_s'],s['processes'][label]) for s in samples if label in s['processes']]
        summary['process_cpu_percent'][label]=distribution([
            100*(b['cpu_ticks']-a['cpu_ticks'])/os.sysconf('SC_CLK_TCK')/(tb-ta)
            for (ta,a),(tb,b) in zip(readings,readings[1:])
            if a['pid']==b['pid'] and tb>ta])
    cameras=[s['camera'] for s in samples if s.get('camera',{}).get('state')=='LIVE']
    summary['camera_counter_delta']={key:cameras[-1][key]-cameras[0][key]
        for key in ('sequence','copy_discards','busy_skips','obsolete_discards')
        if len(cameras)>1 and cameras[0]['session']==cameras[-1]['session']}
    if args.vision_url:
        values=list(unique.values())
        summary['unique_results_observed']=len(values)
        summary['valid_observed_fps']=len(values)/duration
        summary['vision_states']={state:sum(s.get('vision',{}).get('state')==state for s in samples) for state in set(s.get('vision',{}).get('state') for s in samples)}
        timed=[s for s in samples if 'processed' in s.get('vision',{})]
        if len(timed)>1:
            summary['inference_fps']=(timed[-1]['vision']['processed']-timed[0]['vision']['processed'])/(timed[-1]['elapsed_s']-timed[0]['elapsed_s'])
        for key in ('inference_ms','native_inference_ms','age_ms','bridge_input_bytes'):
            summary[key]=distribution([v[key] for v in values if key in v])
        for section in ('native_timings_ms','bridge_timings_ms','source_timings_ms'):
            keys=set(k for v in values for k in v.get(section,{}))
            summary[section]={k:distribution([v[section][k] for v in values if k in v.get(section,{})]) for k in keys}
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))


if __name__=='__main__': main()
