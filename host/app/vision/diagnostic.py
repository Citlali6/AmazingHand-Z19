"""Bounded COCO diagnostic labels; display/grasp mappings remain independent."""
import math
COCO_NAMES = (
    'person','bicycle','car','motorcycle','airplane','bus','train','truck','boat',
    'traffic light','fire hydrant','stop sign','parking meter','bench','bird','cat',
    'dog','horse','sheep','cow','elephant','bear','zebra','giraffe','backpack','umbrella',
    'handbag','tie','suitcase','frisbee','skis','snowboard','sports ball','kite',
    'baseball bat','baseball glove','skateboard','surfboard','tennis racket','bottle',
    'wine glass','cup','fork','knife','spoon','bowl','banana','apple','sandwich',
    'orange','broccoli','carrot','hot dog','pizza','donut','cake','chair','couch',
    'potted plant','bed','dining table','toilet','tv','laptop','mouse','remote',
    'keyboard','cell phone','microwave','oven','toaster','sink','refrigerator',
    'book','clock','vase','scissors','teddy bear','hair drier','toothbrush')


def named_rows(rows):
    for row in rows:
        if (len(row)!=6 or not all(math.isfinite(float(v)) for v in row)
                or not 0<=row[0]<80 or int(row[0])!=row[0]):
            raise ValueError('invalid COCO diagnostic row')
    return [dict(coco_id=int(row[0]), label=COCO_NAMES[int(row[0])],
                 confidence=row[1], bbox_xyxy=list(row[2:6])) for row in rows]


def describe_native(value):
    value = dict(value)
    for key in ('raw_top','pre_nms_top','post_nms_top'):
        value[key] = named_rows(value[key])
    value['target_class_top'] = [named_rows(rows) for rows in value['target_class_top']]
    value['class_maxima'] = [dict(coco_id=cid,label=COCO_NAMES[cid],confidence=p)
                             for cid,p in enumerate(value['class_maxima'])]
    return value
