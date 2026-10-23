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
from color_control import ControlStore, atomic_json, read_json, target_view
from coordinate_speech import CoordinateSpeech

HTML = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>Z19 语音与 PL 颜色定位</title>
<style>body{font:16px system-ui;background:#101827;color:#eef2ff;margin:18px}h1{font-size:24px}button{font-size:16px;padding:8px 16px;margin:5px;border:0;border-radius:8px;cursor:pointer}main{display:flex;gap:16px}section{width:50%}img{width:100%;background:#000;border-radius:10px}#state,#voice,#target{padding:12px;background:#1e293b;border-radius:8px;margin:10px 0}small{color:#b7c9e2}label{display:inline-block;padding:6px}</style>
<h1>Z19 · 语音选择 / PL 颜色定位</h1>
<div id="voice"><button onclick="voice(true)">开启语音</button><button onclick="voice(false)">暂停语音</button><p id="speech">等待语音状态……</p><small>说“拿取红色物品”，或只说“红色”“绿色”“蓝色”；说“停止”结束定位。语音由板端 ARM 离线识别。</small></div>
<div><button onclick="choose(1)">🔴 红色</button><button onclick="choose(2)">🟢 绿色</button><button onclick="choose(3)">🔵 蓝色</button><button onclick="choose(0)">原图模式</button>
<label>最低饱和度 <input id="sat" type="number" min="0" max="255" value="100" style="width:65px"></label><label>最低亮度 <input id="val" type="number" min="0" max="255" value="80" style="width:65px"></label><button onclick="choose(selected)">应用阈值</button></div>
<div><button onclick="profile('balanced')">流畅坐标 · 高清原图</button><button onclick="profile('hd')">全分辨率 PL · 1280×720</button><button onclick="profile('smooth')">640×480</button><small>流畅坐标模式：720p原图标定，PL颜色处理640×360；保持完整视野。</small></div>
<style>.coordinate-view{position:relative}.coordinate-view img{display:block}.coordinate-view canvas{position:absolute;inset:0;width:100%;height:100%;touch-action:none}#grid-controls{padding:12px;background:#1e293b;border-radius:8px}select{font-size:16px}</style>
<div id="grid-controls"><label><input type="checkbox" id="grid-on" checked>显示实体网格交点坐标</label><span id="grid-readout">等待检测板面交点 · 单位 px · 未标定毫米</span></div>
<div id="state">等待开发板返回图像……</div><div id="target">等待颜色指令……</div><div id="coordinate-target">板面目标中心：等待定位</div><p><label><input type="checkbox" id="speech-on" checked onchange="speechSwitch(this.checked)">定位后播报坐标</label><span id="speech-result">等待语音指令</span></p><main><section><p>USB 摄像头原图 · 网格坐标 (px)</p><div class="coordinate-view"><img id="source" alt="摄像头原图"><canvas id="source-grid" aria-label="原图像素坐标网格"></canvas></div></section><section><p>PL 定位 / 颜色高亮 · 网格坐标 (px)</p><div class="coordinate-view"><img id="pl" alt="FPGA处理图"><canvas id="pl-grid" aria-label="PL图像素坐标网格"></canvas></div></section></main>
<p><small>颜色分割、计数和目标包围框由 FPGA PL 计算；实体网格交点由浏览器检测并标注像素坐标。两图同帧，未标定毫米，尚未驱动机械臂。</small></p>
<script src="/grid_overlay.js"></script>
<script>let stamp=-1,selected=1,busy=false,switching=false;const names=['原图','红色','绿色','蓝色'];let displayedTimes=[],displayFps=0;
async function choose(c){selected=c;let r=await fetch('/control',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({color:c,min_s:Number(document.getElementById('sat').value),min_v:Number(document.getElementById('val').value)})});if(!r.ok)document.getElementById('state').textContent=await r.text();}
async function profile(mode){if(switching)return;switching=true;document.getElementById('state').textContent='正在切换画质……';try{let r=await fetch('/profile',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({mode})});if(!r.ok)throw Error(await r.text());stamp=-1;}catch(e){document.getElementById('state').textContent=e.message;}finally{switching=false;}}
async function voice(enabled){let r=await fetch('/voice',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({enabled})});if(!r.ok)document.getElementById('speech').textContent=await r.text();}
async function speechSwitch(enabled){await fetch('/speech',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({enabled})});}
function controls(s,showTarget=true){
 const v=s.voice||{phase:'unavailable'};
 const phases={loading:'正在加载语音模型',listening:'麦克风已开启，请说指令',speaking:'正在播报，麦克风暂不接收指令',paused:'麦克风已暂停',error:'语音错误',unavailable:'语音环境未配置'};
 let speech=phases[v.phase]||'等待语音状态';
 if(v.partial)speech+=' · 正在听：'+v.partial;else if(v.text)speech+=' · 最近听到：'+v.text;
 if(v.reason==='not_whitelisted')speech+='（颜色不明确或含否定，请重说）';
 if(v.reason==='low_confidence')speech+='（置信度不足，请重说）';
 if(v.accepted&&v.keyword)speech+=' → 关键词：'+v.keyword;
 if(typeof v.peak==='number')speech+=' · 输入峰值 '+Math.round(v.peak/32768*100)+'%';
 if(v.error)speech+=' · '+v.error;
 document.getElementById('speech').textContent=speech;
 const spoken=s.speech||{phase:'unavailable'};
 const speechPhases={idle:'等待语音定位',waiting_target:'等待本次语音指令的有效目标',outside_board:'目标中心超出板面，暂不播报',stabilizing:'等待目标位置稳定',queued:'坐标已就绪',synthesizing:'正在生成中文播报',playing:'正在播报',spoken:'已播报',paused:'播报已暂停',cancelled:'任务变化，已取消旧播报',error:'播报失败',unavailable:'播报环境未配置'};
 document.getElementById('speech-result').textContent=(speechPhases[spoken.phase]||spoken.phase)+(spoken.text?' · '+spoken.text:'')+(spoken.error?' · '+spoken.error:'');
 if(typeof spoken.enabled==='boolean')document.getElementById('speech-on').checked=spoken.enabled;
 if(!showTarget)return;
 const t=s.target||{state:'waiting'};
 const states={waiting:'指令已收到，等待对应的新帧……',stopped:'定位已停止，等待颜色指令',not_found:'当前新帧未发现所选颜色目标',stale:'图像已过期，坐标无效',invalid:'定位数据无效',camera_error:'相机已停止，坐标无效'};
 document.getElementById('target').textContent=t.state==='found'?'PL 目标位置（'+s.width+'×'+s.height+'像素）：左上 ('+t.bbox[0]+', '+t.bbox[1]+')，右下 ('+t.bbox[2]+', '+t.bbox[3]+') · '+t.mask_count+' 匹配像素 · 帧 '+t.frame_sequence:(states[t.state]||'等待定位结果');
 if(s.request)selected=s.request.color;
}
function picture(url,id){return new Promise((resolve,reject)=>{let img=new Image();img.id=id;img.alt=id==='source'?'摄像头原图':'FPGA处理图';img.onload=()=>resolve(img);img.onerror=()=>reject(Error('正在等待新帧……'));img.src=url;});}
async function update(){
 if(busy||switching)return;
 busy=true;
 try{
  let r=await fetch('/status',{cache:'no-store'});
  if(!r.ok)throw Error(await r.text());
  let s=await r.json();controls(s,false);
  if(s.camera_running===false)throw Error('采集已停止，请重新选择画质');
  if(s.age_s>3)throw Error('等待新图像，检查板端采集状态……');
  if(s.published_monotonic!==stamp){
   let suffix='?v='+s.published_monotonic;
   let pair=await Promise.all([picture('/frame-'+s.frame+'-source.jpg'+suffix,'source'),picture('/frame-'+s.frame+'-pl.jpg'+suffix,'pl')]);
   if(switching)return;
   document.getElementById('source').replaceWith(pair[0]);
   document.getElementById('pl').replaceWith(pair[1]);stamp=s.published_monotonic;
   drawCoordinateGrids();
   offerCoordinateSpeech(s);
   const now=performance.now();displayedTimes.push(now);displayedTimes=displayedTimes.filter(t=>now-t<3000);
   displayFps=displayedTimes.length>1?(displayedTimes.length-1)*1000/(now-displayedTimes[0]):0;
  }
  controls(s,true);
  document.getElementById('state').textContent='原图 '+(s.capture_width||s.width)+'×'+(s.capture_height||s.height)+' / PL '+s.width+'×'+s.height+' · '+names[s.color]+' · 板端 '+Number(s.fps||0).toFixed(1)+' / 显示 '+displayFps.toFixed(1)+' 帧/秒 · 采集到发布 '+Math.round(s.capture_to_publish_ms||0)+' ms · 相机/PL帧 '+s.capture_sequence+'/'+s.pl_sequence;
 }catch(e){document.getElementById('state').textContent=e.message;document.getElementById('target').textContent='连接中断或未取得新帧，坐标无效';}
 finally{busy=false;}
}
setInterval(update,25);update();</script></html>'''

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
        if mode not in ('smooth','hd','balanced'):raise ValueError('Unknown profile')
        with self.lock:
            if self.mode==mode and self.process is not None and self.process.poll() is None:return
            self.stop()
            width,height=(640,480) if mode=='smooth' else (1280,720)
            divisor=2 if mode=='balanced' else 1
            with (self.directory/'capture-fast.log').open('ab') as output:
                self.process=subprocess.Popen([self.executable,'/dev/video0',str(width),str(height),str(self.directory),'100000',str(divisor)],stdout=output,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL)
            self.mode=mode


class VoiceManager:
    def __init__(self, assets, directory):
        self.assets=assets.resolve()
        self.directory=directory
        self.process=None
        self.lock=threading.Lock()
        atomic_json(directory/'voice.json',{'phase':'paused','asr_location':'Z19_PS_ARM'})
    def start(self):
        with self.lock:
            if self.process is not None and self.process.poll() is None:return
            atomic_json(self.directory/'voice.json',{'phase':'loading','asr_location':'Z19_PS_ARM','updated_monotonic':time.monotonic()})
            script=Path(__file__).with_name('voice_color.sh')
            with (self.directory/'voice-color.log').open('ab') as output:
                self.process=subprocess.Popen(['sh',str(script),str(self.assets),str(self.directory)],stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.STDOUT)
    def stop(self):
        with self.lock:
            if self.process is not None and self.process.poll() is None:
                self.process.terminate()
                self.process.wait(timeout=7)
    def state(self):
        state=read_json(self.directory/'voice.json',{'phase':'paused'})
        if self.process is not None and self.process.poll() is not None and state.get('phase') not in ('paused','error'):
            state.update(phase='error',error='Voice process exited; check board audio status')
        return state

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--directory',type=Path,required=True)
    parser.add_argument('--port',type=int,default=18774)
    parser.add_argument('--camera',type=Path,help='Own this reviewed native camera executable')
    parser.add_argument('--profile',choices=('smooth','hd','balanced'),default='balanced')
    parser.add_argument('--voice-assets',type=Path)
    parser.add_argument('--listen',action='store_true',help='Start the microphone on launch')
    args=parser.parse_args()
    directory=args.directory.resolve()
    lock=threading.Lock()
    controls=ControlStore(directory)
    voice=VoiceManager(args.voice_assets,directory) if args.voice_assets else None
    speech=CoordinateSpeech(directory,args.voice_assets) if args.voice_assets else None
    if args.listen and voice is None:parser.error('--listen requires --voice-assets')
    if voice:
        controls.write(0,'startup')
        atexit.register(voice.stop)
        if args.listen:voice.start()
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
                    data['voice']=voice.state() if voice else {'phase':'unavailable'}
                    data['request']=read_json(directory/'control.json',{})
                    data['target']=target_view(data,data['request'],data['age_s'])
                    if data.get('camera_running') is False:data['target']={'state':'camera_error','bbox':None}
                    if speech:speech.record(data)
                    data['speech']=speech.snapshot() if speech else {'phase':'unavailable'}
                    return self.reply(200,json.dumps(data).encode(),'application/json')
                if re.fullmatch(r'/frame-[0-9]+-(source|pl)\.jpg',path):
                    return self.reply(200,(directory/path[1:]).read_bytes(),'image/jpeg')
                if path=='/grid_overlay.js':
                    return self.reply(200,Path(__file__).with_name('grid_overlay.js').read_bytes(),'application/javascript; charset=utf-8')
                return self.reply(404,b'Not found')
            except (OSError,ValueError):return self.reply(503,'等待板端完成当前帧……'.encode('utf-8'))
        def do_POST(self):
            if self.path not in ('/control','/profile','/voice','/announce','/speech'):return self.reply(404,b'Not found')
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=2048:raise ValueError()
                data=json.loads(self.rfile.read(length))
                if self.path in ('/announce','/speech'):
                    if not speech:return self.reply(409,b'Speech assets are not configured')
                    if self.path=='/speech':
                        speech.set_enabled(data['enabled'])
                        return self.reply(200,b'OK')
                    return self.reply(200,json.dumps(speech.offer(data)).encode(),'application/json')
                if self.path=='/voice':
                    if not voice:return self.reply(409,b'Voice environment is not configured')
                    if type(data['enabled']) is not bool:raise ValueError()
                    if data['enabled']:voice.start()
                    else:voice.stop()
                    return self.reply(200,b'OK')
                if self.path=='/profile':
                    if not camera:return self.reply(409,b'Camera process is not managed by this server')
                    camera.start(data['mode'])
                    return self.reply(200,b'OK')
                color,sat,val=(data[k] for k in ('color','min_s','min_v'))
                if any(type(v)is not int for v in (color,sat,val)) or not(0<=color<=3 and 0<=sat<=255 and 0<=val<=255):raise ValueError()
                with lock:
                    controls.write(color,'manual',min_s=sat,min_v=val)
                return self.reply(200,b'OK')
            except subprocess.TimeoutExpired:return self.reply(503,b'Previous camera process has not exited; no new process started')
            except (OSError,ValueError,KeyError,TypeError):
                self.close_connection=True
                return self.reply(400,b'Invalid request')
    try:
        http.server.ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
    finally:
        if speech:speech.close()
        if voice:voice.stop()
        if camera:camera.stop()

if __name__=='__main__':main()
