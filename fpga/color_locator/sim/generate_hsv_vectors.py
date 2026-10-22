"""Offline reference vectors only, never part of the deployed camera pipeline."""
import colorsys
from pathlib import Path
import random

rng = random.Random(20261022)
colors = [(255,0,0),(0,255,0),(0,0,255),(255,255,0),(255,0,255),(0,255,255),
          (0,0,0),(255,255,255),(127,127,127),(255,127,0),(255,0,127),
          (80,0,0),(0,80,0),(0,0,80)]
colors += [tuple(rng.randrange(256) for _ in range(3)) for _ in range(1010)]
lines = []
for r,g,b in colors:
    h,s,v = colorsys.rgb_to_hsv(r/255,g/255,b/255)
    word = (r<<40)|(g<<32)|(b<<24)|(round(h*180)%180<<16)|(round(s*255)<<8)|round(v*255)
    lines.append(f'{word:012x}')
Path('vectors.hex').write_text('\n'.join(lines)+'\n',encoding='ascii')
print(len(lines))
