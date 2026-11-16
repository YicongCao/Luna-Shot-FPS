from pathlib import Path
from PIL import Image
import numpy as np,json
D=Path(__file__).resolve().parents[2]/'docs/validation/ls01-refine-v2'
def im(name):return np.asarray(Image.open(D/(name+'.png')).convert('RGB')).astype(float)/255
probes=json.loads((D/'spill-probes.json').read_text());sides={}
for side in ['-1','1']:
 delta=im(f'spill-{side}-on')-im(f'spill-{side}-off');regions={}
 for name,(x,y) in probes[side].items():
  x,y=round(x),round(y);d=delta[y-16:y+17,x-16:x+17]
  regions[name]={'mean_rgb_delta':d.mean(axis=(0,1)).tolist(),'pixels_gaining_cyan':int(np.count_nonzero((d[:,:,1]+d[:,:,2])*.5>.008)),'probe_center':[x,y]}
 sides[side]={'regions':regions,'cyan_gain_pixels':int(np.count_nonzero((delta[:,:,1]+delta[:,:,2])*.5>.01))}
a=im('spill-blocker-shadow-on');b=im('spill-blocker-shadow-off');gain=(b-a)[:,:,1:].mean(-1)
shadow={'pixels_darker_with_shadow':int(np.count_nonzero(gain>.015)),'mean_gain_without_shadow':float(gain.mean())}
passed=all(v['cyan_gain_pixels']>1000 and all(r['pixels_gaining_cyan']>10 for r in v['regions'].values()) for v in sides.values()) and shadow['pixels_darker_with_shadow']>1000
r={'sides':sides,'occlusion':shadow,'passed':passed,'method':'fixed camera/exposure; two off/on images; 33x33 projected receiver/copper/rim/shroud probes; actual shadows-only blocker'}
(D/'spill-pixels.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2));assert passed
