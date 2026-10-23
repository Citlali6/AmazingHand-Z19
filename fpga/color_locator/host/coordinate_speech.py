"""Z19 PS: validated PL box + browser board homography -> local Chinese TTS.

No image detection, MMIO, network synthesis, robot commands or stored recordings.
"""
from collections import OrderedDict, deque
import math
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import wave

from color_control import atomic_json, read_json, target_view


def spoken_coordinate(value):
    """Spell a board coordinate in Chinese, retaining exactly one decimal place.

    Piper's Chinese frontend can discard the dot in Arabic decimal numbers.
    Use the same rounding as the numeric display, but explicitly pronounce 点.
    """
    if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 40:
        raise ValueError('Coordinate must be within the 0..40 cm board range')
    digits = '零一二三四五六七八九'
    whole, fraction = ('%.1f' % value).split('.')
    integer = int(whole)
    if integer < 10:
        words = digits[integer]
    else:
        tens, units = divmod(integer, 10)
        words = (digits[tens] if tens > 1 else '')+'十'
        if units:
            words += digits[units]
    return words+'点'+digits[int(fraction)]


class CoordinateSpeech:
    def __init__(self, directory, assets):
        self.directory = Path(directory)
        self.assets = Path(assets)
        self.lock = threading.RLock()
        self.condition = threading.Condition(self.lock)
        self.frames = OrderedDict()
        self.samples = deque(maxlen=3)
        self.queued_ids = deque(maxlen=64)
        self.pending = None
        self.process = None
        self.stopping = threading.Event()
        self.state = dict(phase='idle', text='', coordinate_frame='board_xy_cm',
                          center_definition='PL_global_bbox_center', enabled=True)
        self.thread = threading.Thread(target=self._worker, daemon=True)
        self.thread.start()

    def snapshot(self):
        with self.lock:
            result = dict(self.state)
            request = read_json(self.directory/'control.json', {})
            if (request.get('source') == 'voice' and request.get('color') in (1, 2, 3) and
                    request.get('request_id') != result.get('request_id')):
                result.update(phase='waiting_target', request_id=request['request_id'], text='', tts_text='', error=None)
            return result

    def record(self, frame):
        with self.lock:
            self.frames[frame['frame']] = dict(frame)
            while len(self.frames) > 24:
                self.frames.popitem(last=False)

    def _active(self, request_id):
        request = read_json(self.directory/'control.json', {})
        return (not self.stopping.is_set() and self.state['enabled'] and
                request.get('request_id') == request_id and
                request.get('source') == 'voice' and request.get('color') in (1, 2, 3))

    def offer(self, payload):
        request_id = payload['request_id']
        if type(request_id) is not int or not self._active(request_id):
            return {'accepted': False, 'reason': 'inactive_voice_request'}
        matrix = payload['matrix']
        if (not isinstance(matrix, list) or len(matrix) != 9 or
                any(type(v) not in (float, int) or not math.isfinite(v) for v in matrix)):
            raise ValueError('Invalid homography')
        quality = payload['quality']
        if (type(quality['checks']) is not int or quality['checks'] < 5 or
                any(type(quality[k]) not in (int, float) or not math.isfinite(quality[k])
                    for k in ('mean_mm', 'max_mm')) or
                not 0 <= quality['mean_mm'] <= 3 or not 0 <= quality['max_mm'] <= 6):
            raise ValueError('Invalid grid quality')
        with self.lock:
            if self.state.get('request_id') != request_id:
                self.state.update(phase='waiting_target', request_id=request_id, text='', tts_text='', error=None,
                                  x_cm=None, y_cm=None)
            if request_id in self.queued_ids:
                return {'accepted': False, 'reason': 'already_announced_or_queued'}
            frame = self.frames.get(payload['frame'])
            request = read_json(self.directory/'control.json', {})
            if (not frame or frame.get('capture_sequence') != payload['capture_sequence'] or
                    frame.get('request_id') != request_id or
                    time.monotonic()-frame['published_monotonic'] > 1 or
                    target_view(frame, request, time.monotonic()-frame['published_monotonic'])['state'] != 'found' or
                    frame.get('mask_count', 0) < 50):
                self.samples.clear()
                return {'accepted': False, 'reason': 'waiting_fresh_pl_target'}
            box = frame['bbox']
            u = (box[0]+box[2])/2/frame['width']
            v = (box[1]+box[3])/2/frame['height']
            denominator = matrix[6]*u+matrix[7]*v+matrix[8]
            if abs(denominator) < 1e-8:
                raise ValueError('Degenerate coordinate projection')
            x = 400*(matrix[0]*u+matrix[1]*v+matrix[2])/denominator
            y = 300*(matrix[3]*u+matrix[4]*v+matrix[5])/denominator
            if not (math.isfinite(x) and math.isfinite(y) and 0 <= x <= 400 and 0 <= y <= 300):
                self.samples.clear()
                self.state.update(phase='outside_board', text='')
                return {'accepted': False, 'reason': 'target_outside_board'}
            sample = dict(request_id=request_id, sequence=frame['capture_sequence'],
                          x=x, y=y, stamp=frame['published_monotonic'])
            if self.samples and (self.samples[-1]['request_id'] != request_id or
                                 sample['stamp']-self.samples[-1]['stamp'] > .8):
                self.samples.clear()
            if not self.samples or self.samples[-1]['sequence'] != sample['sequence']:
                self.samples.append(sample)
            if (len(self.samples) < 3 or self.samples[-1]['stamp']-self.samples[0]['stamp'] < .2 or
                    any(math.hypot(p['x']-x, p['y']-y) > 8 for p in self.samples)):
                self.state.update(phase='stabilizing', request_id=request_id)
                return {'accepted': False, 'reason': 'stabilizing'}
            x_cm = round(sum(p['x'] for p in self.samples)/len(self.samples)/10, 1)
            y_cm = round(sum(p['y'] for p in self.samples)/len(self.samples)/10, 1)
            name = {1: '红色', 2: '绿色', 3: '蓝色'}[frame['color']]
            text = '%s物品，横坐标%.1f厘米，纵坐标%.1f厘米。' % (name, x_cm, y_cm)
            tts_text = '%s物品，横坐标%s厘米，纵坐标%s厘米。' % (
                name, spoken_coordinate(x_cm), spoken_coordinate(y_cm))
            self.pending = dict(request_id=request_id, text=text, tts_text=tts_text, x_cm=x_cm, y_cm=y_cm,
                                capture_sequence=frame['capture_sequence'], matrix=list(matrix))
            self.queued_ids.append(request_id)
            self.state.update(self.pending, phase='queued')
            self.condition.notify()
            return {'accepted': True, 'text': text}

    def set_enabled(self, enabled):
        if type(enabled) is not bool:
            raise ValueError('Invalid speech switch')
        with self.condition:
            self.state['enabled'] = enabled
            if not enabled:
                self.pending = None
                self.samples.clear()
                self.state['phase'] = 'paused'
                if self.process and self.process.poll() is None:
                    self.process.terminate()
            else:
                self.state['phase'] = 'idle'

    def _run(self, command, env, request_id, timeout, input_bytes=None):
        with tempfile.TemporaryFile() as errors:
            child = subprocess.Popen(command, stdin=subprocess.PIPE if input_bytes else subprocess.DEVNULL,
                                     stdout=subprocess.DEVNULL, stderr=errors, env=env)
            with self.lock:
                self.process = child
            if input_bytes:
                child.stdin.write(input_bytes)
                child.stdin.close()
            deadline = time.monotonic()+timeout
            while child.poll() is None:
                if not self._active(request_id) or time.monotonic() > deadline:
                    child.terminate()
                    try:
                        child.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        child.kill()
                        child.wait(timeout=2)
                    raise RuntimeError('Speech cancelled or timed out')
                self.stopping.wait(.08)
            if child.returncode:
                errors.seek(0)
                raise RuntimeError('Local speech failed: '+errors.read()[-400:].decode('utf-8', 'replace'))
            with self.lock:
                self.process = None

    def _speak(self, job):
        request_id = job['request_id']
        piper_dir = self.assets/'neural-tts/piper'
        model = self.assets/'neural-tts/zh_CN-huayan-medium.onnx'
        native = self.assets/'native'
        environment = dict(os.environ, OMP_NUM_THREADS='1', OPENBLAS_NUM_THREADS='1')
        synth_env = dict(environment, LD_LIBRARY_PATH=str(piper_dir))
        synth_env.pop('ESPEAK_DATA_PATH', None)
        player_env = dict(environment,
                          LD_LIBRARY_PATH='%s/lib/aarch64-linux-gnu:%s/usr/lib/aarch64-linux-gnu:%s/usr/lib/aarch64-linux-gnu/pulseaudio' % (native, native, native),
                          ALSA_CONFIG_PATH=str(native/'usr/share/alsa/alsa.conf'),
                          ALSA_CONFIG_DIR=str(native/'usr/share/alsa'))
        with tempfile.TemporaryDirectory(prefix='coordinate-tts-', dir=str(self.directory)) as folder:
            path = Path(folder)/'speech.wav'
            with self.lock:
                self.state.update(job, phase='synthesizing', error=None)
            self._run([str(piper_dir/'piper'), '--model', str(model), '--output_file', str(path),
                       '--espeak_data', str(piper_dir/'espeak-ng-data')],
                      synth_env, request_id, 35, (job['tts_text']+'\n').encode('utf-8'))
            with wave.open(str(path), 'rb') as audio:
                duration = audio.getnframes()/audio.getframerate()
                if duration <= 0 or duration > 25 or audio.getsampwidth() != 2:
                    raise RuntimeError('Invalid synthesized speech')
            if not self._active(request_id):
                raise RuntimeError('Voice request changed before playback')
            current = read_json(self.directory/'status.json', {})
            request = read_json(self.directory/'control.json', {})
            if (not current or target_view(current, request, time.monotonic()-current.get('published_monotonic', 0))['state'] != 'found'):
                raise RuntimeError('目标已丢失，请重新发出指令')
            box = current['bbox']
            u, v = (box[0]+box[2])/2/current['width'], (box[1]+box[3])/2/current['height']
            matrix = job['matrix']
            d = matrix[6]*u+matrix[7]*v+matrix[8]
            if abs(d) < 1e-8:
                raise RuntimeError('标定投影无效')
            x, y = 400*(matrix[0]*u+matrix[1]*v+matrix[2])/d, 300*(matrix[3]*u+matrix[4]*v+matrix[5])/d
            if math.hypot(x-job['x_cm']*10, y-job['y_cm']*10) > 10:
                raise RuntimeError('目标已移动，请重新发出指令')
            atomic_json(self.directory/'speech_guard.json', {'until': time.monotonic()+duration+2})
            with self.lock:
                self.state.update(phase='playing')
            try:
                self._run([str(native/'usr/bin/aplay'), '-q', '-D', 'plughw:CARD=Device,DEV=0', str(path)],
                          player_env, request_id, duration+8)
            finally:
                atomic_json(self.directory/'speech_guard.json', {'until': time.monotonic()+.9})
            with self.lock:
                self.state.update(phase='spoken', completed_monotonic=time.monotonic())

    def _worker(self):
        while not self.stopping.is_set():
            with self.condition:
                if self.pending is None:
                    self.condition.wait(timeout=.5)
                job = self.pending
                self.pending = None
            if job is None:
                continue
            try:
                if self._active(job['request_id']):
                    self._speak(job)
            except Exception as error:
                with self.lock:
                    if self.state.get('request_id') == job['request_id']:
                        self.state.update(phase='error' if self._active(job['request_id']) else 'cancelled', error=str(error))

    def close(self):
        self.stopping.set()
        with self.condition:
            self.condition.notify()
            if self.process and self.process.poll() is None:
                self.process.terminate()
        self.thread.join(timeout=4)
