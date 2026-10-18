"""One fixed ROI probe; private PC feasibility only, never board acceptance."""
import hashlib
import json
import os
from pathlib import Path

ROOT = Path('F:/Amazing_Hand')
OUT = Path(__file__).resolve().parent / 'roi-feasibility-once'
OUT.mkdir(exist_ok=False)
os.environ['YOLO_CONFIG_DIR'] = str(OUT / 'ultralytics-settings')
os.environ['TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD'] = '1'
import cv2
import numpy as np
import torch
from ultralytics import YOLO
from ultralytics.utils.ops import non_max_suppression, scale_boxes

torch.set_num_threads(4)
weights = ROOT / 'tmp/vision-20261018/export416-pinned/yolov8n.pt'
expected = json.loads((ROOT/'docs/fpga/evidence/live_vision_20261018/model_manifest.json').read_text())
assert hashlib.sha256(weights.read_bytes()).hexdigest() == expected['weights_sha256']
model = YOLO(str(weights)).model.eval().float()
samples = {
    'apple': ROOT/'tmp/vision-review-20261018/apple-resumed/first-result.jpg',
    'thermos': ROOT/'tmp/vision-review-20261018/adjusted/first-result.jpg',
    'car': ROOT/'tmp/vision-20261018/arm-car-steady/same-frame.jpg',
    'hand': ROOT/'tmp/vision-20261018/camera-first.jpg',
}
records = []
for name, path in samples.items():
    data = path.read_bytes()
    image = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    height, width = image.shape[:2]
    # Single policy chosen before inference: central 70% width, entire height.
    # No class-specific ROI, threshold sweep, training or deployment changes.
    x1, x2 = int(width*.15), int(width*.85)
    roi = image[:,x1:x2]
    rh, rw = roi.shape[:2]
    size = 416
    ratio = min(size/rh,size/rw)
    nw, nh = int(np.floor(rw*ratio+.5)), int(np.floor(rh*ratio+.5))
    left, top = (size-nw)//2, (size-nh)//2
    padded = cv2.copyMakeBorder(cv2.resize(roi,(nw,nh)),top,size-nh-top,left,size-nw-left,
                               cv2.BORDER_CONSTANT,value=(114,114,114))
    tensor = torch.from_numpy(np.ascontiguousarray(padded[:,:,::-1].transpose(2,0,1))).float().div(255).unsqueeze(0)
    with torch.inference_mode():
        pred = model(tensor)[0]
    raw = pred[0].cpu().numpy()
    detections = non_max_suppression(pred.clone(),conf_thres=.35,iou_thres=.45)[0]
    detections[:,:4] = scale_boxes((size,size),detections[:,:4],roi.shape[:2])
    rows = []
    for row in detections:
        box = row[:4].tolist()
        box[0] += x1
        box[2] += x1
        rows.append(dict(coco_id=int(row[5]),label=model.names[int(row[5])],confidence=float(row[4]),bbox_xyxy_original=box))
    records.append(dict(sample=name,source_local=str(path),source_jpeg_sha256=hashlib.sha256(data).hexdigest(),
        source_size=[width,height],roi_xyxy=[x1,0,x2,height],input_size=[416,416],resized=[nw,nh],
        padding_ltrb=[left,top,size-nw-left,size-nh-top],conf=.35,iou=.45,
        class_maxima={model.names[c]:float(raw[4+c].max()) for c in [2,39,47,49]},detections=rows))
record = dict(role='PC CPU feasibility only; neither live nor board acceptance',
    policy='One fixed central70%-width full-height ROI for all four existing real images',
    weights_sha256=hashlib.sha256(weights.read_bytes()).hexdigest(),
    limitations='Four convenience archival images, no orange/empty-background dataset; ROI may crop peripheral objects; no recall claim; no production changes',
    samples=records)
(OUT/'result.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(json.dumps(record,indent=2))
