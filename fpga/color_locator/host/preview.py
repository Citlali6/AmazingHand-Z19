"""Board-only display transport. No camera/HSV/coordinate algorithms in Python."""
import argparse
import atexit
import http.server
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import threading
import time
from urllib.parse import urlsplit

HTML = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>Z19 FPGA 颜色识别验证</title>
<style>body{font:18px system-ui;background:#101827;color:#eef2ff;margin:26px}h1{font-size:26px}button{font-size:18px;padding:10px 22px;margin:6px;border:0;border-radius:8px;cursor:pointer}main{display:flex;gap:18px}section{width:50%}img{width:100%;background:#000;border-radius:10px}#state{padding:14px;background:#1e293b;border-radius:8px;margin:14px 0}small{color:#b7c9e2}label{display:inline-block;padding:8px}</style>
<h1>Z19 · FPGA 颜色识别验证</h1><p>选择颜色后，右侧保留匹配区域，其他区域由 FPGA 压暗。</p>
<div><button onclick="choose(1)">🔴 红色</button><button onclick="choose(2)">🟢 绿色</button><button onclick="choose(3)">🔵 蓝色</button><button onclick="choose(0)">原图模式</button>
<label>最低饱和度 <input id="sat" type="number" min="0" max="255" value="100" style="width:65px"></label><label>最低亮度 <input id="val" type="number" min="0" max="255" value="80" style="width:65px"></label><button onclick="choose(selected)">应用阈值</button></div>
<div><button onclick="profile('smooth')">流畅 · 640×480</button><button onclick="profile('hd')">高清 · 1280×720</button><small>切换约需 1 秒；识别仍在 FPGA 中运行。</small></div>
<div id="state">等待开发板返回图像……</div><main><section><p>USB 摄像头原图</p><img id="source" alt="摄像头原图"></section><section><p>真实 PL 处理结果</p><img id="pl" alt="FPGA处理图"></section></main>
<p><small>识别运行在 Z19 的 PL 中；板端 ARM 负责 USB、JPEG 和传输，电脑只显示。两图来自同一帧，持续丢弃积压旧帧。尚未接语音或机械臂。</small></p>
<script>let stamp=-1,selected=1,busy=false,switching=false;const names=['原图','红色','绿色','蓝色'];
async function choose(c){selected=c;let r=await fetch('/control',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({color:c,min_s:Number(document.getElementById('sat').value),min_v:Number(document.getElementById('val').value)})});if(!r.ok)document.getElementById('state').textContent=await r.text();}
async function profile(mode){if(switching)return;switching=true;document.getElementById('state').textContent='正在切换画质……';try{let r=await fetch('/profile',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({mode})});if(!r.ok)throw Error(await r.text());stamp=-1;}catch(e){document.getElementById('state').textContent=e.message;}finally{switching=false;}}
function picture(url,id){return new Promise((resolve,reject)=>{let img=new Image();img.id=id;img.alt=id==='source'?'摄像头原图':'FPGA处理图';img.onload=()=>resolve(img);img.onerror=()=>reject(Error('正在等待新帧……'));img.src=url;});}
async function update(){if(busy||switching)return;busy=true;try{let r=await fetch('/status',{cache:'no-store'});if(!r.ok)throw Error(await r.text());let s=await r.json();if(s.camera_running===false)throw Error('采集已停止，请重新选择画质');if(s.age_s>3)throw Error('等待新图像，检查板端采集状态……');if(s.published_monotonic!==stamp){let suffix='?v='+s.published_monotonic;let pair=await Promise.all([picture('/frame-'+s.frame+'-source.jpg'+suffix,'source'),picture('/frame-'+s.frame+'-pl.jpg'+suffix,'pl')]);if(switching)return;document.getElementById('source').replaceWith(pair[0]);document.getElementById('pl').replaceWith(pair[1]);stamp=s.published_monotonic;}document.getElementById('state').textContent=s.width+'×'+s.height+' · '+names[s.color]+' · '+Number(s.fps||0).toFixed(1)+' 帧/秒 · 采集到发布 '+Math.round(s.capture_to_publish_ms||0)+' ms · 匹配 '+s.mask_count+' 像素 · 相机/PL帧 '+s.capture_sequence+'/'+s.pl_sequence;}catch(e){document.getElementById('state').textContent=e.message;}finally{busy=false;}}setInterval(update,80);update();</script></html>'''

class CaptureManager:
    """Only owns the camera process it creates; no FPGA loading or other PIDs."""
    def __init__(self, executable, directory):
        self.executable=str(executable.resolve())
        self.directory=directory
        self.lock=threading.Lock()
        self.process=None
        self.mode=None
    def stop(self):
        if self.process is not None and self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
    def start(self, mode):
        if mode not in ('smooth','hd'):raise ValueError('Unknown profile')
        with self.lock:
            if self.mode==mode and self.process is not None and self.process.poll() is None:return
            self.stop()
            width,height=(640,480) if mode=='smooth' else (1280,720)
            with (self.directory/'capture-fast.log').open('ab') as output:
                self.process=subprocess.Popen([self.executable,'/dev/video0',str(width),str(height),str(self.directory),'100000'],stdout=output,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL)
            self.mode=mode

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--directory',type=Path,required=True)
    parser.add_argument('--port',type=int,default=18774)
    parser.add_argument('--camera',type=Path,help='Own this reviewed native camera executable')
    parser.add_argument('--profile',choices=('smooth','hd'),default='smooth')
    args=parser.parse_args()
    directory=args.directory.resolve()
    lock=threading.Lock()
    camera=CaptureManager(args.camera,directory) if args.camera else None
    if camera:
        camera.start(args.profile)
        atexit.register(camera.stop)
    def shutdown_signal(_signum,_frame):
        raise SystemExit(0)
    signal.signal(signal.SIGTERM,shutdown_signal)
    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version='HTTP/1.1'
        def setup(self):
            super().setup()
            self.connection.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1)
        def log_message(self,*args): pass
        def reply(self,status,body,kind='text/plain; charset=utf-8'):
            self.send_response(status);self.send_header('Content-Type',kind);self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        def do_GET(self):
            try:
                path=urlsplit(self.path).path
                if path=='/':return self.reply(200,HTML.encode('utf-8'),'text/html; charset=utf-8')
                if path=='/status':
                    data=json.loads((directory/'status.json').read_text())
                    data['age_s']=max(0,time.monotonic()-data['published_monotonic'])
                    if camera:data['camera_running']=camera.process is not None and camera.process.poll() is None
                    return self.reply(200,json.dumps(data).encode(),'application/json')
                if re.fullmatch(r'/frame-[0-9]+-(source|pl)\.jpg',path):
                    return self.reply(200,(directory/path[1:]).read_bytes(),'image/jpeg')
                return self.reply(404,b'Not found')
            except (OSError,ValueError):return self.reply(503,'等待板端完成当前帧……'.encode('utf-8'))
        def do_POST(self):
            if self.path not in ('/control','/profile'):return self.reply(404,b'Not found')
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=512:raise ValueError()
                data=json.loads(self.rfile.read(length))
                if self.path=='/profile':
                    if not camera:return self.reply(409,b'Camera process is not managed by this server')
                    camera.start(data['mode'])
                    return self.reply(200,b'OK')
                color,sat,val=(data[k] for k in ('color','min_s','min_v'))
                if any(type(v)is not int for v in (color,sat,val)) or not(0<=color<=3 and 0<=sat<=255 and 0<=val<=255):raise ValueError()
                with lock:
                    temp=directory/'control.tmp';temp.write_text('%d %d %d\n'%(color,sat,val));os.replace(str(temp),str(directory/'control.txt'))
                return self.reply(200,b'OK')
            except subprocess.TimeoutExpired:return self.reply(503,b'Previous camera process has not exited; no new process started')
            except (OSError,ValueError,KeyError,TypeError):
                self.close_connection=True
                return self.reply(400,b'Invalid request')
    try:
        http.server.ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
    finally:
        if camera:camera.stop()

if __name__=='__main__':main()
