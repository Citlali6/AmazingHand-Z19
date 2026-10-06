import argparse,json,time,io,threading,subprocess,hashlib,os
from pathlib import Path
from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from PIL import Image
ROOT=Path(__file__).parent
parser=argparse.ArgumentParser()
parser.add_argument('--build',required=True,type=Path)
parser.add_argument('--xsct',default='F:/Xilinx/Vitis/2020.1/bin/xsct.bat')
parser.add_argument('--port',default=8765,type=int)
args=parser.parse_args()
BUILD=args.build.resolve()
manifest=json.loads((BUILD/'manifest.json').read_text(encoding='utf-8-sig'))
if hashlib.sha256((BUILD/'capture.elf').read_bytes()).hexdigest()!=manifest['elf_sha256']:
 raise SystemExit('ELF differs from manifest; rebuild before preview')
OUT=ROOT/'runtime'/time.strftime('%Y%m%d-%H%M%S')
OUT.mkdir(parents=True,exist_ok=False)
HTML="""<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>Z19 Camera</title>
<style>body{background:#111827;color:#e5e7eb;font:18px system-ui;margin:32px auto;max-width:900px}h1{font-size:26px}img{width:640px;max-width:100%;border:1px solid #4b5563}button{padding:8px 16px;font-size:16px}#status{margin:18px 0;white-space:pre-line}.hint{color:#9ca3af}input{width:260px}</style>
<h1>Z19 &#31532;&#19968;&#36335;&#25668;&#20687;&#22836;&#23454;&#26102;&#39044;&#35272;</h1><img id="image" alt="Waiting for frame"><div id="status">Connecting...</div>
<p class="hint">1920x1080 capture / 320x180 JTAG preview. Low refresh rate.</p>
<label>&#23545;&#28966;&#20301;&#32622; <input type="range" min="0" max="1023" value="300" id="focus" oninput="document.getElementById('fv').textContent=this.value"><span id="fv">300</span></label>
<button onclick="fetch('/focus',{method:'POST',body:document.getElementById('focus').value})">&#24212;&#29992;&#23545;&#28966;</button>
<button id="stop" onclick="fetch('/stop',{method:'POST'}).then(()=>{this.disabled=true;this.textContent='Stop requested'})">&#20572;&#27490;&#37319;&#38598;</button>
<script>let prev=-1;async function update(){try{let s=await(await fetch('/status',{cache:'no-store'})).json();if(s.sequence!==prev&&s.sequence){prev=s.sequence;document.getElementById('image').src='/frame.jpg?seq='+prev}document.getElementById('status').textContent=`Preview: ${s.sequence||0} | ${(s.preview_fps||0).toFixed(1)} fps | Age: ${(s.age_seconds||0).toFixed(1)} s\nBoard frames: ${s.board_frames||0} | Focus: ${s.focus} (result=${s.focus_result})\n${s.state}`;}catch(e){document.getElementById('status').textContent='Preview service disconnected';}setTimeout(update,250)}update()</script></html>
"""
lock=threading.Lock();latest_jpeg=None;latest_meta={};last_update=0;start=time.monotonic();count=0
def watch():
 global latest_jpeg,latest_meta,count,last_update
 last=0
 while True:
  try:
   items=sorted(OUT.glob('frame_*.json'))
   if items:
    path=items[-1];m=json.loads(path.read_text())
    if m['sequence']!=last:
     raw=path.with_suffix('.raw').read_bytes()
     if len(raw)!=320*180*3:raise ValueError('Incomplete frame')
     im=Image.frombytes('RGB',(320,180),raw);b=io.BytesIO();im.save(b,format='JPEG',quality=95)
     count+=1;last=m['sequence'];m['preview_fps']=count/(time.monotonic()-start);m['sha256']=hashlib.sha256(raw).hexdigest()
     with lock:latest_jpeg=b.getvalue();latest_meta=m;last_update=time.monotonic()
     evidence.write(json.dumps(m)+'\n')
     if count<=3:im.save(OUT/f'preview_{count:03d}.png')
     for old in items[:-8]:
      try:old.with_suffix('.raw').unlink(missing_ok=True);old.unlink(missing_ok=True)
      except OSError:pass
  except (OSError,ValueError):pass
  time.sleep(.05)
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*a):pass
 def do_GET(self):
  if self.path.startswith('/frame.jpg'):
   with lock:data=latest_jpeg
   if data is None:self.send_error(503);return
   typ='image/jpeg'
  elif self.path=='/status':
   with lock:m=dict(latest_meta);m['age_seconds']=time.monotonic()-last_update if last_update else 0
   if proc.poll() is not None:m['state']='STOPPED' if proc.returncode==0 else 'ERROR: '+((OUT/'stream_error.txt').read_text() if (OUT/'stream_error.txt').exists() else 'See stream.log')
   else:m['state']='LIVE' if m['age_seconds']<3 else 'STALE - no new frames'
   data=json.dumps(m).encode();typ='application/json'
  else:data=HTML.encode();typ='text/html; charset=utf-8'
  self.send_response(200);self.send_header('Content-Type',typ);self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def do_POST(self):
  if self.path=='/stop':(OUT/'stop.request').write_text('stop')
  elif self.path=='/focus':
   try:
    pos=int(self.rfile.read(min(16,int(self.headers.get('Content-Length',0)))))
    if not 0<=pos<=1023:raise ValueError()
   except ValueError:self.send_error(400);return
   (OUT/'focus.request').write_text(str(pos))
  else:self.send_error(404);return
  self.send_response(200);self.end_headers();self.wfile.write(b'OK')
server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
log=(OUT/'stream.log').open('w',buffering=1,encoding='utf-8')
proc=subprocess.Popen([args.xsct,str(ROOT/'stream.tcl'),str(BUILD),str(OUT)],cwd=str(ROOT),stdout=log,stderr=subprocess.STDOUT)
(OUT/'stream.pid').write_text(str(proc.pid))
evidence=(OUT/'preview_evidence.jsonl').open('w',buffering=1,encoding='utf-8')
threading.Thread(target=watch,daemon=True).start()
(OUT/'viewer.pid').write_text(str(os.getpid()))
print(f'LIVE_VIEWER http://127.0.0.1:{args.port} | runtime {OUT}',flush=True)
server.serve_forever()
