"""USB audio capture and PCM conversion, compatible with board Python 3.7+.

Live Linux conversion is done by ALSA's plug device. No sound device is opened
at import time. File conversion intentionally accepts only PCM16 at 16/32/48 kHz.
"""
from __future__ import annotations

import array
import collections
import os
import re
import select
import shutil
import subprocess
import sys
import threading
import time
import wave
from pathlib import Path

RATE = 16000
SAMPLE_BYTES = 2


def devices():
    """Enumerate ALSA capture devices; listing does not start a recording."""
    if not sys.platform.startswith('linux'):
        raise RuntimeError('USB capture uses Linux ALSA; Windows can use WAV input.')
    executable = shutil.which('arecord')
    if executable is None:
        raise RuntimeError('arecord missing: install alsa-utils matching the board Linux image.')
    env = dict(os.environ, LC_ALL='C')
    result = subprocess.run([executable, '-l'], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, universal_newlines=True,
                            timeout=5, env=env)
    if result.returncode:
        raise RuntimeError('ALSA capture enumeration failed: ' + result.stderr.strip())
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


def select_device(requested=None):
    if requested:
        # plughw performs rate/channel/sample-format conversion. Passing an
        # argv list avoids shell expansion; restrict to an actual capture name.
        if not re.fullmatch(r'plughw:(?:\d+,\d+|CARD=[A-Za-z0-9_-]+,DEV=\d+)', requested):
            raise ValueError('Use an ALSA plughw device from the devices command.')
        return requested
    candidates = [item for item in devices() if item['usb']]
    if len(candidates) != 1:
        raise RuntimeError('Expected one USB capture device, found %d; list devices and select --device.' % len(candidates))
    return candidates[0]['alsa']


class AlsaCapture:
    """One owned arecord child; close interrupts blocking pipe reads."""
    def __init__(self, device=None, chunk_ms=100):
        if not 20 <= chunk_ms <= 500:
            raise ValueError('chunk_ms must be 20..500')
        self.device = device
        self.chunk_bytes = RATE * chunk_ms // 1000 * SAMPLE_BYTES
        self.process = None
        self.errors = collections.deque(maxlen=10)
        self._stderr_thread = None
        self._lock = threading.Lock()
        self._closed = False

    def start(self):
        if not sys.platform.startswith('linux'):
            raise RuntimeError('Live USB capture requires Linux ALSA; use WAV input on Windows.')
        device = select_device(self.device)
        with self._lock:
            if self._closed:
                raise RuntimeError('Capture already closed')
            self.device = device
            executable = shutil.which('arecord')
            if executable is None:
                raise RuntimeError('arecord missing')
            self.process = subprocess.Popen(
                [executable, '-q', '-D', device, '-t', 'raw', '-f', 'S16_LE',
                 '-r', str(RATE), '-c', '1'], stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, env=dict(os.environ, LC_ALL='C'))
        self._stderr_thread = threading.Thread(target=self._drain_errors, daemon=True)
        self._stderr_thread.start()

    def _drain_errors(self):
        for line in self.process.stderr:
            self.errors.append(line.decode('utf-8', errors='replace').strip())

    def read(self):
        chunks, remaining = [], self.chunk_bytes
        deadline = time.monotonic() + 5
        while remaining:
            wait = deadline - time.monotonic()
            if wait <= 0 or not select.select([self.process.stdout], [], [], max(0, wait))[0]:
                raise RuntimeError('USB audio stalled for 5 seconds')
            pcm = os.read(self.process.stdout.fileno(), remaining)
            if not pcm:
                if self._stderr_thread:
                    self._stderr_thread.join(timeout=0.2)
                raise RuntimeError('USB audio capture stopped: ' + '; '.join(self.errors))
            chunks.append(pcm)
            remaining -= len(pcm)
        return b''.join(chunks)

    def close(self):
        with self._lock:
            self._closed = True
            process = self.process
        if process is None:
            return
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
        if self._stderr_thread:
            self._stderr_thread.join(timeout=1)
        # The reader owns stdout; let its read return before the caller joins it.

    def release_pipes(self):
        """Call after closing and joining the reader."""
        if self.process:
            self.process.stdout.close()
            self.process.stderr.close()


def wav_pcm(path, channel='mix', chunk_ms=100):
    """Yield 16kHz mono S16_LE from PCM16 mono/stereo at 16/32/48kHz.

Integer-ratio downsampling uses a short box average. This is a baseline speech
input converter, not a calibrated audio-processing or noise-suppression chain.
"""
    if channel not in ('mix', 'left', 'right'):
        raise ValueError('channel must be mix, left or right')
    if not 20 <= chunk_ms <= 500:
        raise ValueError('chunk_ms must be 20..500')
    with wave.open(str(path), 'rb') as source:
        rate, channels = source.getframerate(), source.getnchannels()
        if (source.getcomptype() != 'NONE' or source.getsampwidth() != 2
                or channels not in (1, 2) or rate not in (16000, 32000, 48000)):
            raise ValueError('WAV requires PCM16, 1/2 channels, 16000/32000/48000 Hz')
        factor = rate // RATE
        while True:
            raw = source.readframes(RATE * chunk_ms // 1000 * factor)
            if not raw:
                return
            samples = array.array('h')
            samples.frombytes(raw)
            if len(samples) % channels:
                raise ValueError('Incomplete WAV channel frame')
            if sys.byteorder != 'little':
                samples.byteswap()
            if channels == 2:
                if channel == 'mix':
                    mono = [(int(samples[i]) + int(samples[i + 1])) // 2
                            for i in range(0, len(samples), 2)]
                else:
                    mono = list(samples[0 if channel == 'left' else 1::2])
            else:
                mono = samples
            converted = array.array('h', (sum(mono[i:i + factor]) // factor
                                          for i in range(0, len(mono) - factor + 1, factor)))
            if sys.byteorder != 'little':
                converted.byteswap()
            if converted:
                yield converted.tobytes()


def write_wav(path, chunks):
    """Exclusive creation: never replace a user's recording."""
    with Path(path).open('xb') as raw:
        with wave.open(raw, 'wb') as target:
            target.setnchannels(1)
            target.setsampwidth(2)
            target.setframerate(RATE)
            for pcm in chunks:
                target.writeframesraw(pcm)
