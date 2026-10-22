"""Offline tests; never access a microphone, speaker, robot or board."""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.voice import echo


USB = dict(card=1, device=0, card_id='Device', alsa='plughw:CARD=Device,DEV=0', usb=True)
OTHER = dict(card=0, device=0, card_id='monitor', alsa='plughw:CARD=monitor,DEV=0', usb=False)


class DevicesTest(unittest.TestCase):
    def test_only_usb_selected(self):
        self.assertEqual(echo.choose_device([OTHER, USB], None, 'input'), USB)

    def test_ambiguous_usb_rejected(self):
        with self.assertRaises(RuntimeError):
            echo.choose_device([USB, dict(USB, card=2)], None, 'input')

    def test_missing_usb_rejected(self):
        with self.assertRaises(RuntimeError):
            echo.choose_device([OTHER], None, 'input')

    def test_explicit_numeric_name(self):
        self.assertEqual(echo.choose_device([OTHER, USB], 'plughw:1,0', 'input'), USB)

    def test_unenumerated_name_rejected(self):
        with self.assertRaises(RuntimeError):
            echo.choose_device([USB], 'plughw:5,0', 'input')

    @patch.object(echo.shutil, 'which', return_value='/fake/aplay')
    @patch.object(echo.subprocess, 'run')
    def test_playback_enumeration(self, run, which):
        run.return_value.stdout = 'card 1: Device [USB PnP Audio Device], device 0: USB Audio [USB Audio]\n'
        run.return_value.returncode = 0
        self.assertEqual(echo.playback_devices()[0]['alsa'], USB['alsa'])


class SpeakerTest(unittest.TestCase):
    def test_missing_model_rejected_before_device_access(self):
        with patch.object(echo.shutil, 'which', return_value='/fake/piper'):
            with self.assertRaises(RuntimeError):
                echo.Speaker(USB, model=None)

    def test_invalid_text(self):
        with patch.object(echo.shutil, 'which', return_value='/fake/espeak'):
            s = echo.Speaker(USB, engine='espeak')
        for text in ('', 'x' * 201, None):
            with self.assertRaises(ValueError):
                s.speak(text)

    def test_piper_uses_utf8_stdin_and_private_libraries(self):
        calls = []
        with tempfile.TemporaryDirectory() as folder:
            model = Path(folder) / 'voice.onnx'
            model.write_bytes(b'mocked, not executable')
            Path(str(model) + '.json').write_text('{}')
            def run(command, **kwargs):
                calls.append((command, kwargs))
                if '--output_file' in command:
                    with wave.open(command[command.index('--output_file') + 1], 'wb') as wav:
                        wav.setnchannels(1)
                        wav.setsampwidth(2)
                        wav.setframerate(22050)
                        wav.writeframes(b'\0\0' * 2205)
                class Result:
                    returncode = 0
                    stderr = b''
                return Result()
            with patch.object(echo.shutil, 'which', side_effect=lambda n: '/fake/' + n), \
                    patch.object(echo.subprocess, 'run', side_effect=run), \
                    patch.object(echo, 'emit'):
                speaker = echo.Speaker(USB, executable='piper', model=model)
                speaker.speak('你好；$(不执行)')
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][1]['input'], '你好；$(不执行)\n'.encode('utf-8'))
        self.assertNotIn('你好', ' '.join(calls[0][0]))
        self.assertNotIn('shell', calls[0][1])
        self.assertEqual(calls[0][1]['env']['LD_LIBRARY_PATH'], str(Path('/fake/piper').resolve().parent))
        self.assertEqual(calls[1][0][3], USB['alsa'])

    def test_failed_synthesis_never_plays(self):
        with patch.object(echo.shutil, 'which', return_value='/fake/espeak'), \
                patch.object(echo.subprocess, 'run') as run:
            run.return_value.returncode = 1
            run.return_value.stderr = b'bad voice'
            with self.assertRaises(RuntimeError):
                echo.Speaker(USB, engine='espeak').speak('你好')
            self.assertEqual(run.call_count, 1)


class EntryTest(unittest.TestCase):
    def test_check_does_not_capture_or_play(self):
        with patch.object(echo.sys, 'platform', 'linux'), \
                patch.object(echo, 'devices', return_value=[USB]), \
                patch.object(echo, 'playback_devices', return_value=[USB]), \
                patch.object(echo, 'AlsaCapture') as capture, \
                patch.object(echo, 'Speaker') as speaker, \
                patch.object(echo, 'emit'), \
                patch.object(echo.signal, 'signal'):
            self.assertEqual(echo.main(['--check']), 0)
            capture.assert_not_called()
            speaker.assert_not_called()

    def test_capture_cleanup_closes_owned_pipes(self):
        from unittest.mock import Mock
        capture = Mock()
        echo.stop_capture(capture)
        capture.close.assert_called_once_with()
        capture.release_pipes.assert_called_once_with()

    def test_event_is_unicode_json(self):
        stream = io.StringIO()
        with patch.object(echo.sys, 'stdout', stream):
            echo.emit('recognized', text='你好')
        self.assertEqual(json.loads(stream.getvalue())['text'], '你好')


if __name__ == '__main__':
    unittest.main()
