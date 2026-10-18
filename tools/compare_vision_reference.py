"""One-image CPU reference diagnosis. Never changes or performs board inference.

Use the existing isolated export venv, original trusted weights and a NEW output
directory. Ultralytics settings are isolated before import. The .01 threshold is
diagnostic only; production comparison remains .35, with fixed square input.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image',type=Path,required=True)
    parser.add_argument('--weights',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--input-size',type=int,default=416)
    parser.add_argument('--top-k',type=int,default=10)
    args=parser.parse_args()
    if args.output.exists() or not 1<=args.top_k<=20 or args.input_size<32 or args.input_size%32:
        parser.error('output must be new; top-k1..20; input-size positive multiple32')
    args.output.mkdir(parents=True)
    os.environ['YOLO_CONFIG_DIR']=str((args.output/'ultralytics-settings').resolve())
    os.environ['TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD']='1'
    import cv2
    import numpy as np
    import torch
    from ultralytics import YOLO
    from ultralytics.data.augment import LetterBox
    from ultralytics.utils.ops import non_max_suppression,scale_boxes
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'host'))
    from app.vision.diagnostic import COCO_NAMES
    assert len(COCO_NAMES)==80
    torch.set_num_threads(4)
    image=cv2.imdecode(np.frombuffer(args.image.read_bytes(),np.uint8),cv2.IMREAD_COLOR)
    if image is None:raise ValueError('invalid JPEG')
    h,w=image.shape[:2];size=args.input_size;scale=min(size/h,size/w)
    # These dimensions match the original bridge at1920x1080. Record parity.
    nw,nh=round(w*scale),round(h*scale);left,top=(size-nw)//2,(size-nh)//2
    padded=cv2.copyMakeBorder(cv2.resize(image,(nw,nh)),top,size-nh-top,left,size-nw-left,
                             cv2.BORDER_CONSTANT,value=(114,114,114))
    official=LetterBox(new_shape=(size,size),auto=False)(image=image)
    rgb=np.ascontiguousarray(padded[:,:,::-1])
    fnv=14695981039346656037
    for byte in rgb.flat:fnv=((fnv^int(byte))*1099511628211)&((1<<64)-1)
    tensor=torch.from_numpy(rgb.transpose(2,0,1).copy()).float().div(255).unsqueeze(0)
    model=YOLO(str(args.weights))
    assert [model.names[c] for c in range(80)]==list(COCO_NAMES), 'COCO label mapping differs'
    with torch.inference_mode():pred=model.model.eval().float()(tensor)[0]
    raw=pred[0].cpu().numpy();assert raw.shape[0]==84
    xyxy=raw[:4].T.copy();xyxy[:,:2]-=xyxy[:,2:]/2;xyxy[:,2:]+=xyxy[:,:2]
    xyxy[:,[0,2]]=(xyxy[:,[0,2]]-left)/scale;xyxy[:,[1,3]]=(xyxy[:,[1,3]]-top)/scale
    xyxy[:,[0,2]]=np.clip(xyxy[:,[0,2]],0,w);xyxy[:,[1,3]]=np.clip(xyxy[:,[1,3]],0,h)
    classes=np.argmax(raw[4:],axis=0);scores=np.max(raw[4:],axis=0)
    def row(n,cid=None):
        c=int(classes[n] if cid is None else cid)
        return dict(coco_id=c,label=COCO_NAMES[c],confidence=float(raw[4+c,n]),bbox_xyxy=xyxy[n].tolist())
    def rank(scores):return np.argsort(-scores)[:args.top_k]
    record=dict(role='PC CPU archival diagnosis only; not board acceptance',
        jpeg_sha256=hashlib.sha256(args.image.read_bytes()).hexdigest(),
        weights_sha256=hashlib.sha256(args.weights.read_bytes()).hexdigest(),
        preprocessing=dict(source_size=[w,h],resized=[nw,nh],padding_ltrb=[left,top,size-nw-left,size-nh-top],
            input_size=size,scale=scale,pixel_order='RGB',normalization='1/255 FP32',
            padded_rgb_fnv1a64=format(fnv,'x'),padded_rgb_channel_sums=rgb.sum(axis=(0,1)).tolist(),
            matches_ultralytics_fixed_square=bool(np.array_equal(padded,official)),opencv=cv2.__version__),
        output_shape_wh=[raw.shape[1],raw.shape[0]],
        class_maxima=[dict(coco_id=c,label=COCO_NAMES[c],confidence=float(p)) for c,p in enumerate(raw[4:].max(axis=1))],
        target_class_top=[[row(n,c) for n in rank(raw[4+c])] for c in (2,39,47,49)],
        raw_top=[row(n) for n in rank(scores)],thresholds={})
    for conf in (.35,.01):
        detections=non_max_suppression(pred.clone(),conf_thres=conf,iou_thres=.45)[0]
        detections[:,:4]=scale_boxes((size,size),detections[:,:4],image.shape[:2])
        record['thresholds'][str(conf)]=dict(conf=conf,iou=.45,
          pre_nms_count=int((scores>=conf).sum()),pre_nms_top=[row(n) for n in rank(scores) if scores[n]>=conf],
          post_nms_count=len(detections),post_nms_top=[dict(coco_id=int(x[5]),label=COCO_NAMES[int(x[5])],
            confidence=float(x[4]),bbox_xyxy=x[:4].tolist()) for x in detections[:args.top_k]])
    (args.output/'reference.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(dict(jpeg_sha256=record['jpeg_sha256'],class_maxima=[record['class_maxima'][c] for c in (2,39,47,49)],
                         production=record['thresholds']['0.35']),indent=2))


if __name__=='__main__':main()
