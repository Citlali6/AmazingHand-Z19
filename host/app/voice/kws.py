"""离线中文命令词识别 —— Vosk 小模型 + 语法限词表（project_framework F1）。

设计：
- 默认使用中文模型解码，再按完整命令白名单与词置信度过滤。
  可选SetGrammar保留，默认关闭；中文分词/词表尚未在真实语音上验证，
  避免把未知语句强制解码成命令。
- 输出结构化指令 :class:`Command`（action + target），对齐
  ``main.VoiceSource`` 协议——``main.py`` 的 MockVoice 换成本类即接入真实语音；
- ``transcribe_wav``：文件驱动入口（PC 无麦克风时的测试/演示路径）。

模型：vosk-model-small-cn-0.22（约42MB；本板真实语音验收待麦克风到货），下载脚本
``tools/download_vosk_model.py``，存放 ``host/models/``（不入 Git）。

命令词表验收目标（F1）：词表内识别可靠、端到端 ≤2s；尚无本板实测数据。
"""

from __future__ import annotations

import json
import collections
import math
import re
import threading
import time
from dataclasses import dataclass
from pathlib import Path

#: 15 类物品中文名 → 内部物品名（grasp_table.json 键）
ZH_OBJECTS: dict[str, str] = {
    "香蕉": "banana", "苹果": "apple", "橙子": "orange", "橘子": "orange",
    "瓶子": "bottle", "杯子": "cup", "水杯": "cup", "玻璃杯": "wine_glass",
    "碗": "bowl", "鼠标": "mouse", "遥控器": "remote", "键盘": "keyboard",
    "手机": "cell_phone", "书": "book", "剪刀": "scissors",
    "玩具熊": "teddy_bear", "牙刷": "toothbrush",
}
#: 动作词 → action
ZH_ACTIONS: dict[str, str] = {
    "抓": "grasp", "拿": "grasp", "捡": "grasp",
    "放": "release", "松": "release", "开": "release",
    "停": "stop", "复位": "reset", "重置": "reset",
}

DEFAULT_MODEL_DIR = Path(__file__).resolve().parents[2] / "models/vosk-model-small-cn-0.22"


@dataclass(frozen=True)
class Command:
    """结构化指令（与 main.Command 契约一致；独立定义避免循环依赖）。"""

    action: str  # grasp / release / stop / reset
    target: str = ""


def grammar_words() -> list[str]:
    """Vosk 语法词表（识别空间=命令词全组合）。"""
    words = list(ZH_ACTIONS)
    words += list(ZH_OBJECTS)
    # 常见填充音节，防止误吞字
    words += ["个", "把", "起", "来", "下", "那个", "这个"]
    return list(dict.fromkeys(words + ['[unk]']))


def parse_zh_command(text: str) -> Command | None:
    """Accept complete, unambiguous whitelist commands, not substrings.

    e.g. '不要抓香蕉' and '打开音乐' must not become movement commands.
    This is a conservative command parser, not general Chinese understanding.
    """
    text = re.sub(r'[\s，。！？、,.!?]+', '', text)
    if text in ("停", "停下", "停止", "停止动作", "急停"):
        return Command('stop')
    if text in ("放", "放下", "释放", "松开", "松手", "张开"):
        return Command('release')
    if text in ("复位", "重置"):
        return Command('reset')
    names = '|'.join(re.escape(name) for name in sorted(ZH_OBJECTS, key=len, reverse=True))
    match = re.fullmatch(r'(?:抓起|抓住|抓|拿起|拿|捡起|捡)(?:那个|这个|一个|个|把)?(' + names + ')', text)
    return Command('grasp', ZH_OBJECTS[match.group(1)]) if match else None


@dataclass(frozen=True)
class RecognitionEvent:
    text: str
    command: Command | None
    confidence: float | None
    reason: str
    created: float

    def as_dict(self):
        return dict(schema='amazinghand.voice/1', text=self.text,
                    accepted=self.command is not None, confidence=self.confidence,
                    reason=self.reason,
                    command=None if self.command is None else dict(
                        action=self.command.action, target=self.command.target))


class ZhCommandKws:
    """Vosk 命令词识别器（VoiceSource 协议实现）。"""

    def __init__(self, model_dir: Path | str = DEFAULT_MODEL_DIR,
                 sample_rate: int = 16000, use_grammar: bool = False,
                 min_confidence: float = 0.65):
        from vosk import Model, KaldiRecognizer  # 延迟导入：mock 模式无需 vosk

        model_dir = Path(model_dir)
        if not model_dir.exists():
            raise FileNotFoundError(
                f"vosk 模型缺失: {model_dir}（运行 tools/download_vosk_model.py）"
            )
        self._model = Model(str(model_dir))
        self._rate = sample_rate
        if sample_rate != 16000 or not 0 <= min_confidence <= 1:
            raise ValueError('Voice profile requires 16000 Hz and confidence in 0..1')
        self.min_confidence = min_confidence
        self.last_event = None
        self._grammar = json.dumps(grammar_words(), ensure_ascii=False)
        self._use_grammar = use_grammar
        self._rec: object | None = None
        self.reset()

    def reset(self) -> None:
        """新建识别器（每条命令独立会话，避免跨命令状态串扰）。"""
        from vosk import KaldiRecognizer

        self._rec = KaldiRecognizer(self._model, self._rate)
        self._rec.SetWords(True)
        if self._use_grammar:
            self._rec.SetGrammar(self._grammar)

    # ------------------------------------------------------------------
    # 流式接口（麦克风路径，板端 run_app.sh 使用）
    # ------------------------------------------------------------------

    def feed(self, pcm_bytes: bytes) -> Command | None:
        """喂一段 16kHz mono int16 PCM；final 文本出现时返回解析结果。"""
        if self._rec is None:
            self.reset()
        if self._rec.AcceptWaveform(pcm_bytes):
            return self._parse_final(json.loads(self._rec.Result()))
        return None

    def finish(self) -> Command | None:
        """音频结束：取 final 结果。"""
        if self._rec is None:
            return None
        cmd = self._parse_final(json.loads(self._rec.FinalResult()))
        self.reset()
        return cmd

    # ------------------------------------------------------------------
    # 文件驱动接口（PC 测试/演示）
    # ------------------------------------------------------------------

    def transcribe_wav(self, wav_path: Path | str) -> str:
        """Single utterance WAV → text; use voice CLI for multi-command files."""
        from .audio import wav_pcm
        self.reset()
        results = []
        for chunk in wav_pcm(wav_path):
            if self._rec.AcceptWaveform(chunk):
                results.append(json.loads(self._rec.Result()))
        results.append(json.loads(self._rec.FinalResult()))
        utterances = [item for item in results if (item.get('text') or '').strip()]
        if len(utterances) > 1:
            text = ' / '.join(item['text'] for item in utterances)
            self.last_event = RecognitionEvent(text, None, None, 'multiple_utterances', time.monotonic())
            return text
        result = utterances[0] if utterances else {}
        self._parse_final(result)
        return result.get('text', '')

    def command_from_wav(self, wav_path: Path | str) -> Command | None:
        """wav → 结构化指令（语音→命令端到端）。"""
        self.transcribe_wav(wav_path)
        return self.last_event.command

    # ------------------------------------------------------------------

    def _parse_final(self, result: dict) -> Command | None:
        text = (result.get("text") or "").replace(" ", "")
        words = result.get('result') or []
        confidence = min(float(word['conf']) for word in words) if words else None
        command = parse_zh_command(text)
        if not text:
            reason = 'empty'
        elif '[unk]' in text:
            reason = 'unknown_words'
        elif command is None:
            reason = 'not_whitelisted'
        elif confidence is None or not math.isfinite(confidence) or not self.min_confidence <= confidence <= 1:
            reason = 'low_confidence'
        else:
            reason = 'accepted'
        if reason != 'accepted':
            command = None
        self.last_event = RecognitionEvent(text, command, confidence, reason, time.monotonic())
        return command

    def take_event(self):
        event, self.last_event = self.last_event, None
        return event


class MicVoiceSource:
    """Linux ALSA → Vosk → bounded, expiring command queue.

    Capture errors propagate to the consumer instead of silently killing a
    background thread. Only this object owns its arecord child.
    """
    def __init__(self, kws: ZhCommandKws, rate: int = 16000, chunk_ms: int = 100,
                 device=None, max_age_s=2.0, repeat_s=1.0):
        from .audio import AlsaCapture
        if rate != 16000 or max_age_s <= 0 or repeat_s < 0:
            raise ValueError('Invalid voice capture profile')
        self._kws = kws
        self._capture = AlsaCapture(device, chunk_ms)
        self._q = collections.deque(maxlen=32)
        self._lock = threading.Lock()
        self._ready = threading.Event()
        self._error = None
        self._max_age = max_age_s
        self._repeat = repeat_s
        self._last_command = None
        self._last_command_at = 0.0
        self._stopped = False
        self._pending_stop = None
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._worker, daemon=True)
        self._thread.start()
        try:
            if not self._ready.wait(timeout=5):
                raise RuntimeError('No audio received within 5 seconds; check device/USB driver')
            self._check_error()
        except BaseException:
            self.close()
            raise

    def _worker(self) -> None:  # pragma: no cover —— 板端运行路径
        try:
            self._capture.start()
            while not self._stop.is_set():
                pcm = self._capture.read()
                self._ready.set()
                self._kws.feed(pcm)
                event = self._kws.take_event()
                if event is None or not event.text:
                    continue
                now = time.monotonic()
                if (event.command is not None and event.command.action != 'stop'
                        and event.command == self._last_command
                        and now - self._last_command_at < self._repeat):
                    continue
                if event.command:
                    self._last_command, self._last_command_at = event.command, now
                with self._lock:
                    if event.command and event.command.action == 'stop':
                        self._q.clear()
                        self._stopped = True
                        self._pending_stop = event
                    elif self._stopped and event.command and event.command.action in ('grasp', 'release'):
                        self._q.append(RecognitionEvent(event.text, None, event.confidence,
                                                        'stop_latched', event.created))
                    else:
                        if event.command and event.command.action == 'reset':
                            self._stopped = False
                        self._q.append(event)
        except Exception as exc:
            if not self._stop.is_set():
                self._error = exc
        finally:
            self._ready.set()
            self._capture.close()

    def _check_error(self):
        if self._error is not None:
            raise RuntimeError('Voice capture/recognition failed: ' + str(self._error)) from self._error

    def poll_event(self):
        self._check_error()
        with self._lock:
            if self._pending_stop is not None:
                event, self._pending_stop = self._pending_stop, None
                return event
            while self._q:
                event = self._q.popleft()
                if time.monotonic() - event.created <= self._max_age:
                    return event
        return None

    def poll_command(self) -> Command | None:
        while True:
            event = self.poll_event()
            if event is None or event.command:
                return None if event is None else event.command

    def close(self) -> None:
        self._stop.set()
        self._capture.close()
        self._thread.join(timeout=3)
        if self._thread.is_alive():
            raise RuntimeError('Voice worker did not stop; do not start a second capture')
        self._capture.release_pipes()
