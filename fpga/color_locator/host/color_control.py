"""Shared PS control transport. No image processing, MMIO or robot commands."""
import contextlib
import json
import os
from pathlib import Path
import re
import tempfile
import time

STOP_PHRASES = {'停止', '停下', '停止识别', '停止定位', '停止抓取', '暂停识别', '取消任务'}
COLORS = {'红色': 1, '绿色': 2, '蓝色': 3}


def parse_command(text):
    normalized = re.sub(r'[\s，。！？、,.!?]+', '', text)
    # The user explicitly requested keyword inference, not exact sentences.
    if any(word in normalized for word in ('不要', '不是', '别拿', '别抓', '不拿', '不抓', '不想', '不能', '没有', '不识别', '不定位', '别停止')):
        return None
    if any(word in normalized for word in ('停止', '停下', '暂停', '取消任务')):
        return {'action': 'stop', 'color': 0, 'keyword': '停止'}
    aliases = {'红色': ('红色', '红颜色', '红的'), '绿色': ('绿色', '绿颜色', '绿的'), '蓝色': ('蓝色', '蓝颜色', '蓝的')}
    found = [name for name, words in aliases.items() if any(word in normalized for word in words)]
    if len(found) != 1:
        return None
    return {'action': 'locate', 'color': COLORS[found[0]], 'keyword': found[0]}


def keyword_grammar(model):
    """Space-separated Chinese model words, with unknown/negative alternatives."""
    phrases = ['[unk]', '停止', '停 下', '停止 识别', '停止 定位', '停止 抓取', '暂停',
               '取消 任务', '不要', '不 要', '不是', '不', '别', '你好', '今天', '测试', '什么', '东西']
    for color in COLORS:
        phrases.extend([color, color[0]+' 色', color+' 的', '要 '+color, '不要 '+color,
                        '不 要 '+color, '不是 '+color, '不 拿 '+color, '别 拿 '+color])
        for noun in ('物品', '物体', '方块', '模块', '东西'):
            phrases.extend([color+' '+noun, '拿 '+color+' '+noun,
                            '拿 取 '+color+' '+noun, '拿取 '+color+' '+noun,
                            '拿起 '+color+' '+noun, '抓取 '+color+' '+noun,
                            '请 拿 '+color+' '+noun, '不要 拿 '+color+' '+noun])
    return [phrase for phrase in phrases if all(word=='[unk]' or model.vosk_model_find_word(word)>=0 for word in phrase.split())]


def atomic_json(path, value):
    path = Path(path)
    descriptor, name = tempfile.mkstemp(prefix=path.name+'.', dir=str(path.parent))
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as output:
            json.dump(value, output, ensure_ascii=False)
            output.write('\n')
        os.replace(name, str(path))
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return default


class ControlStore:
    def __init__(self, directory):
        self.directory = Path(directory)

    @contextlib.contextmanager
    def locked(self):
        import fcntl
        with (self.directory/'control.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            yield

    def write(self, color, source, min_s=None, min_v=None, text='', only_if_request=None):
        if type(color) is not int or color not in (0, 1, 2, 3):
            raise ValueError('Invalid color')
        with self.locked():
            previous = read_json(self.directory/'control.json', {})
            if only_if_request is not None and previous.get('request_id') != only_if_request:
                return None
            saturation = previous.get('min_s', 100) if min_s is None else min_s
            value = previous.get('min_v', 80) if min_v is None else min_v
            if any(type(v) is not int or not 0 <= v <= 255 for v in (saturation, value)):
                raise ValueError('Invalid thresholds')
            stamp = time.monotonic()
            request = dict(request_id=max(int(stamp*1000000), previous.get('request_id', 0)+1),
                           requested_monotonic=stamp, color=color, min_s=saturation,
                           min_v=value, source=source, text=text)
            # Publish metadata first: UI waits for a matching completed PL frame.
            atomic_json(self.directory/'control.json', request)
            descriptor, name = tempfile.mkstemp(prefix='control.', dir=str(self.directory))
            try:
                with os.fdopen(descriptor, 'w') as output:
                    output.write('%d %d %d %d %.9f\n' % (color, saturation, value,
                                 request['request_id'], stamp))
                os.replace(name, str(self.directory/'control.txt'))
            finally:
                if os.path.exists(name):
                    os.unlink(name)
            return request


def target_view(frame, request, age):
    """Format PL register values; do not compute centers/boxes from pixels."""
    if age > 2:
        return {'state': 'stale', 'bbox': None}
    if frame.get('capture_sequence') != frame.get('pl_sequence'):
        return {'state': 'invalid', 'bbox': None}
    if not request or request.get('color', 0) == 0:
        return {'state': 'stopped', 'bbox': None}
    if (frame.get('request_id') != request['request_id'] or
            frame.get('color') != request['color'] or
            frame.get('captured_monotonic', -1) < request['requested_monotonic']):
        return {'state': 'waiting', 'bbox': None}
    # No target: hardware returned zero matching pixels. Never reuse old boxes.
    if frame.get('mask_count', 0) == 0:
        return {'state': 'not_found', 'bbox': None}
    box = frame.get('bbox')
    if (not isinstance(box, list) or len(box) != 4 or
            any(type(v) is not int for v in box) or
            not (0 <= box[0] <= box[2] < frame['width'] and
                 0 <= box[1] <= box[3] < frame['height'])):
        return {'state': 'invalid', 'bbox': None}
    return {'state': 'found', 'bbox': box, 'mask_count': frame['mask_count'],
            'frame_sequence': frame['pl_sequence'], 'request_id': request['request_id']}
