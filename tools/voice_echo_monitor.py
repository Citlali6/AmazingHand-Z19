"""Read-only localhost display for the Z19 voice verification JSONL stream.

Optional PC-only dependency: paramiko. Password is read from a prompt or an
anonymous stdin pipe, never command arguments/files. No board control endpoint.
"""
import argparse
import codecs
import getpass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import re
import threading
import time

PAGE = '''<!doctype html><html lang="zh"><meta charset="utf-8">
<title>Z19 语音实板验证</title><style>
body{font:18px system-ui;background:#f1f5f9;color:#102136;max-width:1000px;margin:32px auto;padding:16px}
section{background:white;padding:24px;border-radius:16px;margin:16px 0}h1{font-size:30px}
#state{color:#036969}#partial{color:#475569;min-height:32px}#heard{font-size:32px;font-weight:600}
li{margin:14px 0;white-space:pre-wrap}.muted{font-size:15px;color:#64748b}</style>
<h1>Z19 麦克风 → 中文识别 → USB 喇叭</h1>
<p class="muted">识别与声音合成均在板子 PS 上运行；本页只读取板端结果。播报时暂停收音。</p>
<section><b id="state">正在连接…</b><p id="partial"></p><div id="heard">等待你说话</div></section>
<section><h2>最近记录</h2><ol id="history"></ol></section>
<p class="muted">本测试不发送机械臂指令、不访问 FPGA 寄存器。文字未显示不代表识别成功。</p>
<script>
async function update(){try{const r=await fetch('/api/status',{cache:'no-store'});const d=await r.json();
document.getElementById('state').textContent=d.status;
document.getElementById('partial').textContent=d.partial?'正在识别：'+d.partial:'';
document.getElementById('heard').textContent=d.recognized||'等待你说话';
const list=document.getElementById('history');list.replaceChildren();
for(const text of d.history.slice().reverse()){const li=document.createElement('li');li.textContent=text;list.appendChild(li)}
}catch(e){document.getElementById('state').textContent='本机显示服务不可达'}setTimeout(update,700)}update();
</script></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True)
    parser.add_argument('--user', default='root')
    parser.add_argument('--known-hosts', required=True)
    parser.add_argument('--log', required=True)
    parser.add_argument('--port', type=int, default=8773)
    parser.add_argument('--password-stdin', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'/[A-Za-z0-9_./-]+', args.log) or '..' in args.log.split('/'):
        parser.error('log must be an absolute simple board path')
    if args.password_stdin:
        import sys
        password = sys.stdin.readline().rstrip('\r\n')
    else:
        password = getpass.getpass('Board SSH password (not saved): ')
    state = dict(status='正在连接板端…', partial='', recognized='', history=[])
    lock, stopped = threading.Lock(), threading.Event()

    def reader():
        import paramiko
        client = paramiko.SSHClient()
        client.load_host_keys(args.known_hosts)
        client.set_missing_host_key_policy(paramiko.RejectPolicy())
        try:
            client.connect(args.host, username=args.user, password=password,
                           look_for_keys=False, allow_agent=False, timeout=8,
                           banner_timeout=8, auth_timeout=8)
            sftp = client.open_sftp()
            offset, remainder = 0, ''
            decoder = codecs.getincrementaldecoder('utf-8')()
            while not stopped.is_set():
                with sftp.open(args.log, 'rb') as source:
                    source.seek(offset)
                    raw = source.read(262144)
                    offset += len(raw)
                if raw:
                    lines = (remainder + decoder.decode(raw)).split('\n')
                    remainder = lines.pop()
                    with lock:
                        for line in lines:
                            if not line.strip():
                                continue
                            event = json.loads(line)
                            kind = event.get('event')
                            if kind == 'listening':
                                state['status'] = '正在收音：请说短中文句子，说完停顿'
                                state['partial'] = ''
                            elif kind == 'model_loading':
                                state['status'] = '板端加载中文模型中'
                            elif kind == 'recognized':
                                state['recognized'] = event.get('text', '')
                                state['history'].append('识别：' + state['recognized'])
                                state['partial'] = ''
                                state['status'] = '识别完成，正在合成播报（暂停收音）'
                            elif kind == 'partial':
                                state['partial'] = event.get('text', '')
                            elif kind == 'playback_started':
                                state['status'] = '正在用 USB 喇叭播报（暂停收音）'
                                state['history'].append('播报：' + event.get('text', ''))
                            elif kind == 'error':
                                state['status'] = '板端错误：' + event.get('error', '')
                            elif kind == 'stopped':
                                state['status'] = '板端语音验证已停止'
                            state['history'] = state['history'][-30:]
                stopped.wait(.5)
            sftp.close()
        except Exception as exc:
            with lock:
                state['status'] = '显示连接中断：' + type(exc).__name__ + '（未自动重启板端）'
        finally:
            client.close()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == '/':
                content, mime = PAGE.encode('utf-8'), 'text/html; charset=utf-8'
            elif self.path == '/api/status':
                with lock:
                    content = json.dumps(state, ensure_ascii=False).encode('utf-8')
                mime = 'application/json; charset=utf-8'
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    worker = threading.Thread(target=reader, daemon=True)
    worker.start()
    print('http://127.0.0.1:%d/' % args.port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stopped.set()
        server.server_close()
        worker.join(timeout=2)


if __name__ == '__main__':
    main()
