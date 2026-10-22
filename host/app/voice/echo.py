"""Z19-only microphone -> Vosk -> local TTS -> USB speaker verification.

No robot commands, FPGA access, network TTS, or permanent audio recordings.
Python 3.7+; existing ALSA capture/model are reused. This is independent of KWS.
"""
from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import wave

from .audio import AlsaCapture, RATE, devices


def emit(event, **fields):
    print(json.dumps(dict(event=event, monotonic_s=time.monotonic(), **fields),
                     ensure_ascii=False), flush=True)


def playback_devices():
    executable = shutil.which('aplay')
    if not executable:
        raise RuntimeError('aplay missing: board requires compatible alsa-utils')
    result = subprocess.run([executable, '-l'], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, universal_newlines=True,
                            env=dict(os.environ, LC_ALL='C'), timeout=5)
    if result.returncode:
        raise RuntimeError('Playback enumeration failed: ' + result.stderr.strip())
    found = []
    for line in result.stdout.splitlines():
        match = re.match(r'card (\d+): (\S+) \[(.*?)\], device (\d+): (.*)', line)
        if match:
            card, identifier, label, device, description = match.groups()
            found.append(dict(card=int(card), card_id=identifier, label=label,
                              device=int(device), description=description,
                              alsa='plughw:CARD=%s,DEV=%s' % (identifier, device),
                              usb='usb' in (label + ' ' + description).lower()))
    return found


def choose_device(candidates, requested, label):
    """Explicit names must refer to an actually enumerated device."""
    if requested:
        matched = [d for d in candidates if requested in
                   (d['alsa'], 'plughw:%d,%d' % (d['card'], d['device']))]
    else:
        matched = [d for d in candidates if d['usb']]
    if len(matched) != 1:
        raise RuntimeError('%s requires exactly one matching device; found %d. '
                           'Use --check and select an explicit device.' % (label, len(matched)))
    return matched[0]


class Speaker:
    def __init__(self, device, executable=None, voice='cmn', engine='piper', model=None):
        self.device = device
        self.engine = engine
        self.model = Path(model).resolve() if model else None
        self.executable = shutil.which(executable) if executable else (
            shutil.which('piper') if engine == 'piper' else
            (shutil.which('espeak-ng') or shutil.which('espeak')))
        if not self.executable:
            raise RuntimeError('Local TTS missing: provide board-compatible ' + engine)
        if engine == 'piper' and (self.model is None or not self.model.is_file()
                                  or not Path(str(self.model) + '.json').is_file()):
            raise RuntimeError('Piper requires --tts-model ONNX and adjacent .onnx.json')
        self.player = shutil.which('aplay')
        if not self.player:
            raise RuntimeError('aplay missing')
        self.voice = voice

    def speak(self, text):
        if not isinstance(text, str) or not text.strip() or len(text) > 200:
            raise ValueError('Speech text must contain 1..200 characters')
        # TemporaryDirectory owns only this invocation's synthesized speech.
        with tempfile.TemporaryDirectory(prefix='visiongrasp-voice-') as folder:
            path = str(Path(folder) / 'speech.wav')
            env = dict(os.environ)
            if self.engine == 'piper':
                binary_dir = str(Path(self.executable).resolve().parent)
                # Piper bundles a different eSpeak ABI. Keep it private to its
                # process, and never mix it with the older ALSA/eSpeak runtime.
                env['LD_LIBRARY_PATH'] = binary_dir
                env.pop('ESPEAK_DATA_PATH', None)
                command = [self.executable, '--model', str(self.model), '--output_file', path,
                           '--espeak_data', str(Path(binary_dir) / 'espeak-ng-data')]
            else:
                command = [self.executable, '-v', self.voice, '-b', '1', '-s', '145', '-w', path, '--stdin']
            started = time.monotonic()
            result = subprocess.run(command, input=(text + '\n').encode('utf-8'),
                                    env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    timeout=60)
            if result.returncode:
                raise RuntimeError('Chinese TTS failed: ' + result.stderr.decode('utf-8', 'replace')[-600:])
            with wave.open(path, 'rb') as source:
                if source.getnframes() == 0 or source.getsampwidth() != 2 or source.getcomptype() != 'NONE':
                    raise RuntimeError('TTS did not generate nonempty PCM16 WAV')
                duration = source.getnframes() / source.getframerate()
            emit('playback_started', text=text, output=self.device['alsa'], tts_engine=self.engine,
                 synthesis_seconds=round(time.monotonic() - started, 3))
            result = subprocess.run([self.player, '-q', '-D', self.device['alsa'], path],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    timeout=min(180, duration + 15))
            if result.returncode:
                raise RuntimeError('USB playback failed: ' + result.stderr.decode('utf-8', 'replace')[-600:])
            emit('playback_completed', audible_result='requires_operator_confirmation')


def stop_capture(capture):
    if capture is not None:
        try:
            capture.close()
        finally:
            capture.release_pipes()


def listen(model_path, input_device, speaker, seconds, cooldown):
    # Lazy import: diagnostics and speaker-only verification do not need Vosk.
    from vosk import Model, KaldiRecognizer, SetLogLevel
    if not model_path.is_dir():
        raise RuntimeError('Vosk Chinese model directory missing: ' + str(model_path))
    SetLogLevel(-1)
    emit('model_loading', path=str(model_path), processor='Z19_PS_CPU')
    model = Model(str(model_path))
    recognizer = KaldiRecognizer(model, RATE)
    speaker.speak('语音系统已就绪，请说一句中文。')
    deadline = time.monotonic() + seconds
    capture = None
    last_partial = None
    try:
        while time.monotonic() < deadline:
            if capture is None:
                capture = AlsaCapture(device=input_device['alsa'])
                capture.start()
                emit('listening', input=input_device['alsa'], sample_rate=RATE)
            pcm = capture.read()
            if recognizer.AcceptWaveform(pcm):
                text = ''.join(json.loads(recognizer.Result()).get('text', '').split())
                last_partial = None
                if not text:
                    continue
                emit('recognized', text=text, source='live_usb_microphone', processor='Z19_PS_CPU')
                # Close and drain the owned capture process before speaker output;
                # recreate it afterward so buffered self-speech is never replayed.
                stop_capture(capture)
                capture = None
                if len(text) > 180:
                    emit('utterance_rejected', reason='over_180_characters')
                else:
                    speaker.speak('你说的是，' + text)
                time.sleep(cooldown)
                recognizer.Reset()
            else:
                partial = json.loads(recognizer.PartialResult()).get('partial', '')
                if partial and partial != last_partial:
                    last_partial = partial
                    emit('partial', text=partial)
    finally:
        stop_capture(capture)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true', help='enumerate only; no recording/playback')
    mode.add_argument('--speak', metavar='TEXT', help='synthesize and play one Chinese phrase')
    mode.add_argument('--listen', action='store_true', help='live recognition and speaker repetition')
    parser.add_argument('--model', type=Path, default=Path(__file__).resolve().parents[2] / 'models/vosk-model-small-cn-0.22')
    parser.add_argument('--input-device')
    parser.add_argument('--output-device')
    parser.add_argument('--tts-executable')
    parser.add_argument('--tts-engine', choices=['piper', 'espeak'], default='piper')
    parser.add_argument('--tts-model', type=Path)
    parser.add_argument('--voice', default='cmn', help='installed eSpeak Chinese voice identifier')
    parser.add_argument('--seconds', type=float, default=600)
    parser.add_argument('--cooldown', type=float, default=.7)
    args = parser.parse_args(argv)
    if not math.isfinite(args.seconds) or not 1 <= args.seconds <= 3600:
        parser.error('--seconds must be 1..3600')
    if not math.isfinite(args.cooldown) or not .3 <= args.cooldown <= 3:
        parser.error('--cooldown must be .3..3')
    if not sys.platform.startswith('linux'):
        parser.error('This entry point requires Linux ALSA on Z19')
    def interrupted(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    try:
        outputs = playback_devices()
        if args.check:
            emit('environment', input_devices=devices(), output_devices=outputs,
                 tts_executable=shutil.which(args.tts_executable) if args.tts_executable else
                 (shutil.which('piper') if args.tts_engine == 'piper' else
                  (shutil.which('espeak-ng') or shutil.which('espeak'))),
                 tts_engine=args.tts_engine, tts_model_exists=bool(args.tts_model and args.tts_model.is_file()),
                 model_exists=args.model.is_dir(), board_audio_verified=False)
            return 0
        output = choose_device(outputs, args.output_device, 'USB output')
        speaker = Speaker(output, args.tts_executable, args.voice, args.tts_engine, args.tts_model)
        if args.speak:
            speaker.speak(args.speak)
        else:
            inp = choose_device(devices(), args.input_device, 'USB microphone')
            listen(args.model, inp, speaker, args.seconds, args.cooldown)
        emit('stopped', reason='completed')
        return 0
    except KeyboardInterrupt:
        emit('stopped', reason='operator_stop')
        return 130
    except Exception as exc:
        emit('error', error=str(exc), board_audio_verified=False)
        return 1


if __name__ == '__main__':
    sys.exit(main())
