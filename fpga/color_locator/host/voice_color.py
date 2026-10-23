"""Z19 PS offline ASR -> whitelisted color request; pixels/coordinates stay in PL."""
import argparse
import array
import fcntl
import json
import math
import os
from pathlib import Path
import signal
import threading
import time

from color_control import ControlStore, atomic_json, read_json, parse_command, keyword_grammar


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--model', type=Path, required=True)
    parser.add_argument('--device')
    parser.add_argument('--min-confidence', type=float, default=0.65)
    args = parser.parse_args()
    if not 0 <= args.min_confidence <= 1 or not math.isfinite(args.min_confidence):
        raise ValueError('Invalid confidence threshold')
    lock = open('/run/visiongrasp-voice-color.lock', 'a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    status_path = args.directory/'voice.json'
    controls = ControlStore(args.directory)
    stopping = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stopping.set())
    signal.signal(signal.SIGINT, lambda *_: stopping.set())
    status = dict(schema='visiongrasp.voice-color/1', asr_location='Z19_PS_ARM',
                  localization='Z19_PL', phase='loading', text='', partial='',
                  accepted=False, confidence=None, last_command=None)
    def publish(**updates):
        status.update(updates)
        status['updated_monotonic'] = time.monotonic()
        atomic_json(status_path, status)
    publish()
    capture = None
    stopper = None
    owned_request = None
    failed = False
    try:
        from vosk import Model, KaldiRecognizer, SetLogLevel
        from app.voice.audio import AlsaCapture
        SetLogLevel(-1)
        model = Model(str(args.model))
        grammar = keyword_grammar(model)
        recognizer = KaldiRecognizer(model, 16000, json.dumps(grammar, ensure_ascii=False))
        recognizer.SetWords(True)
        if stopping.is_set():
            return
        capture = AlsaCapture(device=args.device, chunk_ms=100)
        capture.start()
        stopper = threading.Thread(target=lambda: (stopping.wait(), capture.close()), daemon=True)
        stopper.start()
        publish(phase='listening', device=capture.device, inference='color_keywords', grammar_phrases=len(grammar), peak=0, rms=0)
        previous_partial = ''
        last_accept = ('', 0.0)
        heartbeat = time.monotonic()
        muted = False
        while not stopping.is_set():
            pcm = capture.read()
            if stopping.is_set():
                break
            samples = array.array('h', pcm)
            peak = max((abs(value) for value in samples), default=0)
            rms = math.sqrt(sum(value*value for value in samples)/max(1, len(samples)))
            status.update(peak=peak, rms=round(rms, 1))
            guard = read_json(args.directory/'speech_guard.json', {})
            if guard.get('until', 0) > time.monotonic():
                if not muted:
                    recognizer.Reset()
                    previous_partial = ''
                    publish(phase='speaking', partial='', accepted=False)
                muted = True
                continue  # Drain live PCM while discarding speaker output and its echo.
            if muted:
                recognizer.Reset()
                publish(phase='listening', partial='', accepted=False)
                muted = False
            if recognizer.AcceptWaveform(pcm):
                result = json.loads(recognizer.Result())
                text = result.get('text', '').strip()
                previous_partial = ''
                if not text:
                    publish(partial='')
                    continue
                words = result.get('result') or []
                command = parse_command(text)
                keyword = command.get('keyword', '') if command else ''
                relevant = [w for w in words if w.get('word') in (keyword, keyword[:1])]
                confidence = min((float(w.get('conf', 0)) for w in (relevant or words)), default=0)
                reason = 'accepted'
                if command is None:
                    reason = 'not_whitelisted'
                elif not math.isfinite(confidence) or confidence < args.min_confidence:
                    reason = 'low_confidence'
                elif text == last_accept[0] and time.monotonic()-last_accept[1] < 1:
                    reason = 'duplicate'
                if reason == 'accepted':
                    request = controls.write(command['color'], 'voice', text=text)
                    owned_request = request['request_id']
                    last_accept = (text, time.monotonic())
                    publish(phase='listening', text=text, partial='', accepted=True, keyword=keyword,
                            confidence=confidence, reason=reason, last_command=request)
                    # No transcript logging: only latest RAM status holds the text.
                    print('VOICE_COLOR_ACCEPTED request=%d color=%d' % (owned_request, command['color']), flush=True)
                else:
                    publish(phase='listening', text=text, partial='', accepted=False,
                            confidence=confidence, reason=reason)
            else:
                partial = json.loads(recognizer.PartialResult()).get('partial', '')
                if partial != previous_partial or time.monotonic()-heartbeat > 1:
                    previous_partial = partial
                    heartbeat = time.monotonic()
                    publish(partial=partial)
    except Exception as error:
        if not stopping.is_set():
            failed = True
            publish(phase='error', partial='', error=str(error))
    finally:
        stopping.set()
        if capture:
            if stopper:
                stopper.join(timeout=4)
            else:
                capture.close()
            capture.release_pipes()
        if owned_request is not None:
            controls.write(0, 'voice_error' if failed else 'voice_paused', only_if_request=owned_request)
        if not failed:
            publish(phase='paused', partial='')
        lock.close()


if __name__ == '__main__':
    main()
