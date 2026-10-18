"""USB voice foundation CLI: diagnostics/recording/recognition, no hardware control.

python -m app.voice --help (working directory: host/).
All commands except listen/record leave the microphone unopened.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import platform
import shutil
import subprocess
import sys
import time
import wave
from pathlib import Path

from .audio import AlsaCapture, RATE, devices, wav_pcm, write_wav
from .kws import MicVoiceSource, ZhCommandKws, parse_zh_command

DEFAULT_CONFIG = Path(__file__).resolve().parents[2] / 'config' / 'voice_usb.json'


def configuration(path=DEFAULT_CONFIG):
    path = Path(path).resolve()
    data = json.loads(path.read_text(encoding='utf-8'))
    expected = {'device', 'model_dir', 'sample_rate', 'channels', 'sample_bytes',
                'chunk_ms', 'min_confidence', 'max_age_s', 'repeat_s'}
    if not isinstance(data, dict) or set(data) != expected:
        raise ValueError('Voice configuration fields differ from the supplied template')
    for key in ('sample_rate', 'channels', 'sample_bytes', 'chunk_ms',
                'min_confidence', 'max_age_s', 'repeat_s'):
        if type(data[key]) not in (int, float) or not math.isfinite(data[key]):
            raise ValueError('Voice configuration requires finite numeric ' + key)
    if type(data['chunk_ms']) is not int:
        raise ValueError('chunk_ms must be an integer')
    if not isinstance(data['model_dir'], str) or not data['model_dir']:
        raise ValueError('model_dir must be a nonempty path')
    if (data['sample_rate'], data['channels'], data['sample_bytes']) != (16000, 1, 2):
        raise ValueError('Voice output profile must be 16000 Hz, mono PCM16')
    if (not 20 <= data['chunk_ms'] <= 500 or not 0 <= data['min_confidence'] <= 1
            or data['max_age_s'] <= 0 or data['repeat_s'] < 0):
        raise ValueError('Invalid voice timing/confidence configuration')
    if data['device'] is not None and not isinstance(data['device'], str):
        raise ValueError('device must be null or an ALSA plughw name')
    data['model_dir'] = (path.parent / data['model_dir']).resolve()
    return data


def recognizer(config, model=None):
    return ZhCommandKws(model_dir=model or config['model_dir'],
                        min_confidence=config['min_confidence'])


def microphone(config, model=None, device=None):
    return MicVoiceSource(recognizer(config, model), device=device or config['device'],
                          chunk_ms=config['chunk_ms'], max_age_s=config['max_age_s'],
                          repeat_s=config['repeat_s'])


def emit(value):
    print(json.dumps(value, ensure_ascii=False), flush=True)


def parser():
    root = argparse.ArgumentParser(description='USB麦克风基础工具：采音、离线识别、命令输出')
    root.add_argument('--config', type=Path, default=DEFAULT_CONFIG)
    sub = root.add_subparsers(dest='mode', required=True)
    sub.add_parser('devices', help='列出Linux录音设备，不打开麦克风')
    sub.add_parser('check', help='报告运行环境和模型文件，不录音、不加载固件')
    text = sub.add_parser('text', help='文本命令解析，输出JSON，不运行识别模型')
    text.add_argument('text')
    normalize = sub.add_parser('normalize', help='将支持的PCM16 WAV转换为16kHz单声道')
    normalize.add_argument('input', type=Path)
    normalize.add_argument('output', type=Path)
    normalize.add_argument('--channel', choices=['mix', 'left', 'right'], default='mix')
    wav = sub.add_parser('wav', help='从已有录音识别，按句输出JSON')
    wav.add_argument('input', type=Path)
    wav.add_argument('--model', type=Path)
    wav.add_argument('--channel', choices=['mix', 'left', 'right'], default='mix')
    for name, help_text in [('record', '录制WAV，不执行识别'), ('listen', '实时识别，仅输出命令JSON')]:
        item = sub.add_parser(name, help=help_text)
        item.add_argument('--device', help='例如 plughw:CARD=Device,DEV=0；省略时仅允许唯一USB录音设备')
        item.add_argument('--seconds', type=float, default=10 if name == 'record' else 60)
        if name == 'record':
            item.add_argument('output', type=Path)
        else:
            item.add_argument('--model', type=Path)
    return root


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        config = configuration(args.config)
        if args.mode == 'devices':
            emit(dict(devices=devices()))
        elif args.mode == 'check':
            model = config['model_dir']
            emit(dict(python=platform.python_version(), machine=platform.machine(),
                      system=platform.system(), arecord=shutil.which('arecord'),
                      vosk_installed=importlib.util.find_spec('vosk') is not None,
                      model=str(model), model_files_present=all((model / f).is_file()
                          for f in ('am/final.mdl', 'conf/mfcc.conf')),
                      configured_device=config['device'], capture='not_opened',
                      hardware_validation='pending_microphone', control='not_connected'))
        elif args.mode == 'text':
            command = parse_zh_command(args.text)
            emit(dict(schema='amazinghand.voice/1', source='text', text=args.text,
                      accepted=command is not None, confidence=None,
                      reason='text_parser_only', command=None if command is None else
                      dict(action=command.action, target=command.target)))
        elif args.mode == 'normalize':
            write_wav(args.output, wav_pcm(args.input, channel=args.channel))
            emit(dict(output=str(args.output), rate=RATE, channels=1, sample_bytes=2))
        elif args.mode == 'wav':
            kws = recognizer(config, args.model)
            sequence = 0
            for pcm in wav_pcm(args.input, channel=args.channel):
                kws.feed(pcm)
                event = kws.take_event()
                if event and event.text:
                    sequence += 1
                    emit(dict(event.as_dict(), source='wav', seq=sequence))
            kws.finish()
            event = kws.take_event()
            if event and event.text:
                emit(dict(event.as_dict(), source='wav', seq=sequence + 1))
        elif args.mode == 'record':
            if not 0 < args.seconds <= 3600:
                raise ValueError('seconds must be >0 and <=3600')
            capture = AlsaCapture(args.device or config['device'], config['chunk_ms'])
            # Exclusive open happens before starting capture. Invalid devices
            # leave a partial recording, never replace an existing user file.
            with args.output.open('xb') as raw:
                with wave.open(raw, 'wb') as output:
                    output.setnchannels(1)
                    output.setsampwidth(2)
                    output.setframerate(RATE)
                    try:
                        capture.start()
                        remaining = int(args.seconds * RATE) * 2
                        while remaining:
                            pcm = capture.read()[:remaining]
                            output.writeframesraw(pcm)
                            remaining -= len(pcm)
                    finally:
                        capture.close()
                        capture.release_pipes()
            emit(dict(output=str(args.output), rate=RATE, channels=1, sample_bytes=2))
        elif args.mode == 'listen':
            if not 0 < args.seconds <= 3600:
                raise ValueError('seconds must be >0 and <=3600')
            source = microphone(config, args.model, args.device)
            sequence = 0
            try:
                deadline = time.monotonic() + args.seconds
                while time.monotonic() < deadline:
                    event = source.poll_event()
                    if event:
                        sequence += 1
                        emit(dict(event.as_dict(), source='microphone', seq=sequence))
                    else:
                        time.sleep(0.02)
            finally:
                source.close()
        return 0
    except KeyboardInterrupt:
        return 130
    except (RuntimeError, ValueError, OSError, ImportError, wave.Error, subprocess.SubprocessError) as exc:
        print('VOICE_ERROR: ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
