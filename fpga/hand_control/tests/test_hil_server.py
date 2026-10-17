import importlib.util
import json
from pathlib import Path
import socket
import struct
import tempfile
import threading
import unittest

spec = importlib.util.spec_from_file_location('hil_server', Path(__file__).parents[1] / 'ps' / 'hil_server.py')
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


def frame():
    return dict(protocol=server.PROTOCOL, seq=1, heartbeat=1, cmd='grasp', target_raw=[3000]*8,
                feedback=dict(position_raw=[2100]*8, load_raw=[123]*8, online_mask=255))


class BridgeTests(unittest.TestCase):
    def test_rejects_bad_frames(self):
        for key, value in [('seq', True), ('seq', 0), ('heartbeat', 2), ('cmd', 'dance'),
                           ('cmd', []), ('target_raw', [4096]*8), ('target_raw', [1]*7)]:
            request = frame()
            request[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                server.validate(request)
        self.assertIsNone(server.validate(dict(protocol=server.PROTOCOL, cmd='hello')))

    def test_mmap_layout_and_stop_not_target(self):
        # An ordinary file tests data movement, never claims to simulate PL logic.
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'register-file'
            data = bytearray(4096)
            struct.pack_into('<II', data, 0, 0x4148494c, 1)
            path.write_bytes(data)
            device = server.PlDevice(base=0, path=str(path))
            try:
                device.transact(server.validate(frame()))
                self.assertEqual(device.read(8), 3)
                self.assertEqual(device.read(0x20), 3000)
                self.assertEqual(device.read(0x40), 2100)
                self.assertEqual(device.read(0x60), 123)
                device.stop()
                self.assertEqual(device.read(0xf0), 1)
                self.assertEqual(device.read(0x20), 3000)
            finally:
                device.close()

    def test_refuses_legacy_hardware_before_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'wrong-register-file'
            path.write_bytes(bytes(4096))
            with self.assertRaises(RuntimeError):
                server.PlDevice(base=0, path=str(path))
            self.assertEqual(path.read_bytes(), bytes(4096))

    def test_real_socket_ndjson_and_feedback_forwarding(self):
        class RecordingDevice:
            requests = []

            def snapshot(self):
                return dict(accepted_seq=41, source='transport-test-only')

            def transact(self, request):
                self.requests.append(request)
                return dict(seq=request['seq'], target_raw=request['target'], source='transport-test-only')

        device = RecordingDevice()
        client, peer = socket.socketpair()
        errors = []

        def run():
            try:
                with peer:
                    server.serve_connection(peer, device)
            except Exception as error:
                errors.append(error)

        thread = threading.Thread(target=run)
        thread.start()
        with client, client.makefile('rwb') as stream:
            # Split writes verifies framing across TCP-style fragments.
            hello = json.dumps(dict(protocol=server.PROTOCOL, cmd='hello')).encode()+b'\n'
            client.sendall(hello[:8]); client.sendall(hello[8:])
            self.assertEqual(json.loads(stream.readline())['accepted_seq'], 41)
            stream.write(json.dumps(frame()).encode()+b'\n');stream.flush()
            self.assertEqual(json.loads(stream.readline())['target_raw'], [3000]*8)
        thread.join(2)
        self.assertFalse(thread.is_alive())
        self.assertFalse(errors)
        self.assertEqual(device.requests[0]['position'], [2100]*8)
        self.assertEqual(device.requests[0]['load'], [123]*8)


if __name__ == '__main__':
    unittest.main()
