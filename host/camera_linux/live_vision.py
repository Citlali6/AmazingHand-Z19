"""Z19 CPU-only IMX214 inference demo. Never sends hand-control commands.

Python 3.7 + existing OpenCV supported. Browser draws the JPEG and detections
in one immutable JSON result; the PC has no detector or model dependency.
"""
import argparse
import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import platform
import signal
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.vision.camera import CameraUnavailable, DuplicateFrame, PreviewCamera
from app.vision.detector import COCO_TO_ITEM, build_detector

# Display-only COCO labels. car never enters the hand grasp strategy/table.
DISPLAY_CLASSES = dict(COCO_TO_ITEM)
DISPLAY_CLASSES[2] = 'car'

HTML = '''<!doctype html><meta charset="utf-8"><title>Z19 IMX214 board AI</title>
<style>body{background:#101722;color:#ecf0f7;font:18px system-ui;margin:24px}
canvas{max-width:100%;background:#000}pre{white-space:pre-wrap}#state{color:#ffc76b}</style>
<h2>Z19 IMX214 · YOLOv8n / NCNN CPU</h2><p id="state">连接中</p>
<canvas id="view"></canvas><pre id="stats"></pre><p>演示模式：自主抓取禁止；无动作指令。</p>
<script>
let busy=false,deadline=0; const canvas=document.getElementById('view'),ctx=canvas.getContext('2d');
function clearImage(){ctx.clearRect(0,0,canvas.width,canvas.height);canvas.dataset.frameSeq='';canvas.dataset.jpegSha256='';}
function showStats(r){document.getElementById('stats').textContent=JSON.stringify({...r,jpeg_base64:undefined},null,2);}
async function update(){if(busy)return;busy=true;try{
 let started=performance.now(),controller=new AbortController(),timer=setTimeout(()=>controller.abort(),2000);
 let response,r;try{response=await fetch('/result.json',{cache:'no-store',signal:controller.signal});r=await response.json();}finally{clearTimeout(timer);}
 document.getElementById('state').textContent=r.state+' · 自主抓取禁止 · '+(r.error||'');
 if(!r.jpeg_base64){showStats(r);clearImage();return;}
 let im=new Image();im.src='data:image/jpeg;base64,'+r.jpeg_base64;await im.decode();
 deadline=started+r.result_max_age_ms-r.age_ms;
 if(performance.now()>deadline){clearImage();r.state='STALE';showStats(r);document.getElementById('state').textContent='STALE · 自主抓取禁止';return;}
 canvas.width=im.width;canvas.height=im.height;ctx.drawImage(im,0,0);
 for(let d of r.detections){let [x1,y1,x2,y2]=d.bbox_xyxy;ctx.strokeStyle='#63f9ac';ctx.lineWidth=5;
 ctx.strokeRect(x1,y1,x2-x1,y2-y1);ctx.font='28px system-ui';ctx.fillStyle='#63f9ac';
 ctx.fillText(d.category+' '+d.confidence.toFixed(2),x1,Math.max(30,y1-8));}
 canvas.dataset.frameSeq=String(r.frame_seq);canvas.dataset.jpegSha256=r.jpeg_sha256;
 showStats(r);
 }catch(e){document.getElementById('state').textContent='连接中断 · 自主抓取禁止';clearImage();}
 finally{busy=false;}}
setInterval(()=>{if(canvas.dataset.frameSeq&&performance.now()>deadline){clearImage();document.getElementById('state').textContent='STALE · 自主抓取禁止';}},50);
setInterval(update,200);update();</script>'''


def verify_model(directory, input_size):
    manifest = json.loads((directory / 'manifest.json').read_text())
    if manifest['input_size'] != input_size or manifest['model'] != 'yolov8n':
        raise ValueError('model manifest/input size mismatch')
    for name in ('model.ncnn.param', 'model.ncnn.bin'):
        digest = hashlib.sha256((directory / name).read_bytes()).hexdigest()
        if digest != manifest['artifacts'][name]['sha256']:
            raise ValueError('model SHA256 mismatch: ' + name)
    return manifest


def process_usage(pids):
    """Current service + native bridge, excluding the independent preview server."""
    cpu_seconds, rss_kib = 0., 0
    for pid in pids:
        base = Path('/proc/%d' % pid)
        fields = (base / 'stat').read_text().split(') ', 1)[1].split()
        cpu_seconds += (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')
        for line in (base / 'status').read_text().splitlines():
            if line.startswith('VmRSS:'):
                rss_kib += int(line.split()[1])
    return dict(cpu_seconds=cpu_seconds, rss_kib=rss_kib)


class LiveVision:
    def __init__(self, camera, detector, result_max_age_ms=1600, categories=None,
                 input_transport='jpeg', capture_interval_ms=200):
        self.camera, self.detector = camera, detector
        self.result_max_age_ms = result_max_age_ms
        self.categories = set(categories or ('apple', 'banana', 'bottle', 'car'))
        self.input_transport = input_transport
        self.capture_interval_s = capture_interval_ms / 1000.
        self.lock = threading.Lock()
        self.stop = threading.Event()
        self.latest = None
        self.source_error = 'waiting for camera'
        self.source_session = None
        self.result = None
        self.dropped = 0
        self.processed = 0
        self.started = time.monotonic()
        self.threads = []

    def start(self):
        for fn in (self.capture, self.infer):
            worker = threading.Thread(target=fn, daemon=True)
            worker.start()
            self.threads.append(worker)

    def capture(self):
        while not self.stop.is_set():
            try:
                frame = self.camera.read_packet()
                with self.lock:
                    if self.latest is not None:
                        self.dropped += 1
                    self.latest = frame  # One slot: discard old waiting frames.
                    self.source_error = None
                    self.source_session = frame.session
            except DuplicateFrame:
                # Polling may be faster than capture. No new inference work is
                # queued; an already published result retains its original age.
                pass
            except CameraUnavailable as error:
                with self.lock:
                    self.source_error = str(error)
                    self.latest = None
            self.stop.wait(self.capture_interval_s)

    def infer(self):
        while not self.stop.is_set():
            with self.lock:
                packet, self.latest = self.latest, None
            if packet is None:
                self.stop.wait(.02)
                continue
            if packet.age_ms() > self.camera.max_age_ms:
                continue
            started = time.monotonic()
            try:
                deadline = time.monotonic() + (self.camera.max_age_ms-packet.age_ms())/1000
                detections = (self.detector.detect_jpeg(packet.jpeg, packet.width, packet.height, deadline)
                              if self.input_transport == 'jpeg'
                              else self.detector.detect_raw(packet.bgr, deadline))
                elapsed = (time.monotonic() - started) * 1000
                selected = [dict(category=DISPLAY_CLASSES.get(cid), confidence=confidence,
                                 bbox_xyxy=box) for cid,confidence,box in detections
                            if DISPLAY_CLASSES.get(cid) in self.categories]
                self.processed += 1
                usage = process_usage([os.getpid(), self.detector.proc.pid])
                result = dict(state='LIVE' if selected else 'NO_TARGET',
                              frame_seq=packet.sequence, camera_session=packet.session,
                              capture_monotonic=packet.capture_monotonic,
                              age_ms=packet.age_ms(), inference_ms=elapsed,
                              native_inference_ms=getattr(self.detector, 'inference_ms', None),
                              backend=self.detector.name, inference_host=platform.node(),
                              architecture=platform.machine(), pid=os.getpid(),
                              detections=selected, autonomous_grasp_allowed=False,
                              processed=self.processed, dropped_waiting=self.dropped,
                              fps=self.processed / (time.monotonic() - self.started),
                              jpeg_sha256=hashlib.sha256(packet.jpeg).hexdigest(),
                              jpeg_base64=base64.b64encode(packet.jpeg).decode('ascii'),
                              service_and_bridge_rss_kib=usage['rss_kib'],
                              service_and_bridge_cpu_seconds=usage['cpu_seconds'],
                              bridge_pid=self.detector.proc.pid)
                result.update(input_transport=self.input_transport,
                              source_timings_ms=packet.timings_ms,
                              native_timings_ms=getattr(self.detector, 'native_timings_ms', {}),
                              bridge_timings_ms=getattr(self.detector, 'bridge_timings_ms', {}),
                              bridge_input_bytes=getattr(self.detector, 'bridge_input_bytes', None))
                if result['age_ms'] > self.result_max_age_ms:
                    result.update(state='STALE', error='inference result expired', detections=[])
                    result.pop('jpeg_base64', None)
                with self.lock:
                    if self.source_error or packet.session != self.source_session:
                        result.update(state='CAMERA_ERROR', error=self.source_error or 'camera restarted',
                                      detections=[])
                        result.pop('jpeg_base64', None)
                    self.result = (result, packet)
                print(json.dumps({k:v for k,v in result.items() if k != 'jpeg_base64'}), flush=True)
            except CameraUnavailable as error:
                with self.lock:
                    self.result = ({'state':'STALE', 'error':str(error), 'detections':[]}, packet)
            except Exception as error:
                with self.lock:
                    self.result = ({'state':'MODEL_ERROR','error':str(error), 'detections':[]}, packet)
                self.stop.wait(.2)

    def snapshot(self):
        with self.lock:
            if self.source_error:
                return dict(state='CAMERA_ERROR', error=self.source_error, detections=[],
                            autonomous_grasp_allowed=False)
            if self.result is None:
                return dict(state='STARTING', detections=[], autonomous_grasp_allowed=False)
            result, packet = self.result
            value = dict(result, age_ms=packet.age_ms(), autonomous_grasp_allowed=False,
                         result_max_age_ms=self.result_max_age_ms)
            if packet.session != self.source_session:
                return dict(state='CAMERA_RESTARTED', detections=[], autonomous_grasp_allowed=False)
            if packet.age_ms() > self.result_max_age_ms:
                value.update(state='STALE', error='inference result expired', detections=[])
                value.pop('jpeg_base64', None)
            return value

    def close(self):
        self.stop.set()
        # Interrupt a blocked native read before joining the inference worker.
        proc = getattr(self.detector, 'proc', None)
        if proc is not None and proc.poll() is None:
            proc.terminate()
        for worker in self.threads:
            worker.join(timeout=3)
        self.detector.close()
        self.camera.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--camera-url', default='http://127.0.0.1:9000')
    parser.add_argument('--model-dir', type=Path, required=True)
    parser.add_argument('--bridge', required=True)
    parser.add_argument('--input-size', type=int, default=416)
    parser.add_argument('--threads', type=int, default=2)
    parser.add_argument('--input-transport', choices=('bmp','jpeg'), default='jpeg')
    parser.add_argument('--capture-interval-ms', type=float, default=200)
    parser.add_argument('--conf', type=float, default=.35)
    parser.add_argument('--categories', nargs='+', default=['apple','banana','bottle','car'])
    parser.add_argument('--source-max-age-ms', type=float, default=800)
    parser.add_argument('--result-max-age-ms', type=float, default=1600)
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=9100)
    args = parser.parse_args()
    if not 20 <= args.capture_interval_ms <= 500:
        parser.error('capture interval must be between 20 and 500 ms')
    if platform.machine() != 'aarch64':
        parser.error('this demonstration must run on the Z19 ARM64 board')
    manifest = verify_model(args.model_dir, args.input_size)
    detector = build_detector({'vision':{'backend':'ncnn_cpp','conf_threshold':args.conf,
                              'ncnn':dict(model_dir=str(args.model_dir), executable=args.bridge,
                                          input_size=args.input_size, num_threads=args.threads)}})
    pipeline = LiveVision(PreviewCamera(args.camera_url, args.source_max_age_ms,
                                       decode_bgr=args.input_transport != 'jpeg'), detector,
                          args.result_max_age_ms, args.categories, args.input_transport,
                          args.capture_interval_ms)
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == '/':
                body, mime = HTML.encode(), 'text/html; charset=utf-8'
            elif self.path == '/result.json':
                body, mime = json.dumps(pipeline.snapshot()).encode(), 'application/json'
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass
        def log_message(self, *values):
            pass
    server = ThreadingHTTPServer((args.bind,args.port), Handler)
    def terminate(*unused):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGHUP, terminate)
    try:
        print(json.dumps(dict(event='START', architecture=platform.machine(), host=platform.node(),
                              pid=os.getpid(), model=manifest, cpu_only=True)), flush=True)
        pipeline.start()
        server.serve_forever(poll_interval=.2)
    except KeyboardInterrupt:
        pass
    finally:
        pipeline.close()
        server.server_close()


if __name__ == '__main__':
    main()
