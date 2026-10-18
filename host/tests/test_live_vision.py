"""Focused contract checks without models, NCNN, hardware or hand actions."""
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import cv2
import numpy as np
from app.vision.camera import PreviewCamera, CameraUnavailable
from app.vision.backends.ncnn_det import decode_yolov8, letterbox
from app.vision.camera import CameraFrame
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'camera_linux'))
from live_vision import LiveVision


class Response(io.BytesIO):
    def __init__(self, data, headers=None):
        super().__init__(data)
        self.headers = headers or {}


class CameraContract(unittest.TestCase):
    def setUp(self):
        self.camera = PreviewCamera()
        self.image = np.full((20, 40, 3), (10, 20, 200), np.uint8)
        self.jpeg = cv2.imencode('.jpg', self.image)[1].tobytes()
        self.headers = {'X-Sequence':'5', 'X-Capture-Monotonic':'10',
                        'X-Frame-Age-Ms':'10', 'X-Camera-Session':'session-a'}

    def read(self, state='LIVE', headers=None, jpeg=None):
        responses = [Response(json.dumps({'state':state,'sequence':999}).encode()),
                     Response(self.jpeg if jpeg is None else jpeg, headers or self.headers)]
        with patch.object(self.camera.opener, 'open', side_effect=responses):
            return self.camera.read_packet()

    def test_jpeg_headers_bind_identity_not_separate_status(self):
        packet = self.read()
        self.assertEqual(packet.sequence, 5)
        self.assertEqual(packet.jpeg, self.jpeg)
        self.assertEqual(packet.bgr.shape, self.image.shape)

    def test_duplicate_and_reorder_fail(self):
        self.read()
        with self.assertRaises(CameraUnavailable): self.read()
        self.headers['X-Sequence']='4'
        with self.assertRaises(CameraUnavailable): self.read()

    def test_session_restart_accepts_reset_sequence(self):
        self.read()
        self.headers.update({'X-Sequence':'1','X-Camera-Session':'session-b'})
        self.assertEqual(self.read().sequence, 1)

    def test_stale_and_nonfinite_age_fail(self):
        for value in ('801', '-1', 'nan'):
            self.headers['X-Frame-Age-Ms']=value
            with self.assertRaises(CameraUnavailable): self.read()

    def test_missing_identity_or_invalid_jpeg_fail(self):
        with self.assertRaises(CameraUnavailable): self.read(headers={'X-Sequence':'1'})
        with self.assertRaises(CameraUnavailable): self.read(jpeg=b'bad')

    def test_stopped_and_http_failure_fail(self):
        with self.assertRaises(CameraUnavailable): self.read(state='STOPPED')
        with patch.object(self.camera.opener,'open',side_effect=OSError('offline')):
            with self.assertRaises(CameraUnavailable): self.camera.read_packet()


class YoloContract(unittest.TestCase):
    def test_rgb_and_padding(self):
        bgr=np.zeros((20,40,3),np.uint8); bgr[:]=(10,20,200)
        rgb,scale,pad=letterbox(bgr,64)
        self.assertEqual(rgb.shape,(64,64,3))
        self.assertEqual(tuple(rgb[20,20]),(200,20,10))
        self.assertEqual(pad,(0,16))

    def test_layout_nms_clipping_and_class_separation(self):
        pred=np.zeros((3,84),np.float32)
        pred[:,:4]=[20,20,80,80]
        pred[0,4+47]=.9; pred[1,4+47]=.8; pred[2,4+39]=.85
        raw=decode_yolov8(pred,(40,40,3),1,(0,0))
        self.assertEqual([x[0] for x in raw],[47,39])
        self.assertEqual(raw[0][2],(0,0,40,40))
        self.assertEqual(raw,decode_yolov8(pred.T,(40,40,3),1,(0,0)))

    def test_unsupported_head_and_nonfinite_fail(self):
        with self.assertRaises(ValueError): decode_yolov8(np.zeros((12,10)),(40,40,3),1,(0,0))
        pred=np.zeros((84,2)); pred[0,0]=np.nan
        with self.assertRaises(ValueError): decode_yolov8(pred,(40,40,3),1,(0,0))


class PublicationContract(unittest.TestCase):
    def setUp(self):
        self.pipeline=LiveVision(None,None,result_max_age_ms=100)
        self.packet=CameraFrame(np.zeros((2,2,3),np.uint8),b'jpeg',8,'a',1,time.monotonic(),10)
        self.pipeline.source_error=None
        self.pipeline.source_session='a'
        self.pipeline.result=({'state':'LIVE','detections':[{'category':'car'}],
                               'jpeg_base64':'same-frame'},self.packet)

    def test_expiry_clears_boxes_and_image(self):
        with patch.object(CameraFrame,'age_ms',return_value=101):
            value=self.pipeline.snapshot()
        self.assertEqual(value['state'],'STALE')
        self.assertEqual(value['detections'],[])
        self.assertNotIn('jpeg_base64',value)
        self.assertFalse(value['autonomous_grasp_allowed'])

    def test_camera_loss_or_restart_suppresses_old_detection(self):
        self.pipeline.source_error='camera offline'
        self.assertEqual(self.pipeline.snapshot()['state'],'CAMERA_ERROR')
        self.pipeline.source_error=None
        self.pipeline.source_session='b'
        self.assertEqual(self.pipeline.snapshot()['state'],'CAMERA_RESTARTED')


if __name__ == '__main__': unittest.main()
