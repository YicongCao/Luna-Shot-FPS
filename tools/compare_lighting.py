"""Measure fixed-camera native effects and transparent-viewmodel glow, without editing images."""
from pathlib import Path
import json,numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[1];p=R/'docs/validation/lighting-v1'
def rgb(name):return np.asarray(Image.open(p/(name+'.png')).convert('RGB')).astype(float)
rows=[]
for a,b,label in [('00-baseline','01-emission','emission'),('01-emission','02-local-spill','local_spill'),('02-local-spill','03-bloom','bloom'),('03-bloom','04-flare','lens_flare'),('20-lamp-no-bloom','21-lamp-bloom','world_bloom')]:
 x=rgb(a);y=rgb(b);d=np.abs(x-y);count=int(np.any(d>2,axis=2).sum());assert count>50,(label,count)
 rows.append(dict(effect=label,changed_pixels=count,mean_difference=float(d.mean()),max_difference=float(d.max())))
a=np.asarray(Image.open(p/'weapon-no-bloom-rgba.png').convert('RGBA')).astype(float)
raw=Image.open(p/'weapon-bloom-pass.png').convert('RGB')
b=np.asarray(raw.resize((a.shape[1],a.shape[0]),Image.Resampling.BILINEAR)).astype(float)
outside=a[:,:,3]==0;spill=(b.max(2)>2)&outside
x=rgb('02-local-spill');y=rgb('03a-weapon-bloom-only')
alpha_native=np.asarray(Image.fromarray(a[:,:,3].astype(np.uint8)).resize((x.shape[1],x.shape[0]),Image.Resampling.NEAREST))
visible=(np.max(y-x,axis=2)>2)&(alpha_native==0)
assert visible.sum()>20, int(visible.sum())
alpha=dict(raw_glow_pixels_outside_silhouette=int(spill.sum()),visible_composite_pixels_outside_silhouette=int(visible.sum()),visible_glow_outside_silhouette=True,method='Actual rendered cyan highlights, separable blur, additive composition below HUD; native transparent Glow disabled')
# Follow the actual cyan strip silhouette, rather than the old spherical lamp's pixel center.
x=rgb('20-lamp-no-bloom');y=rgb('21-lamp-bloom')
yy,xx=np.indices(x.shape[:2]);central=(abs(xx-640)<250)&(abs(yy-400)<150)
core=central&(x[:,:,2]>180)&(x[:,:,1]>100)&(x[:,:,2]>x[:,:,0]*1.2)
assert core.sum()>20, 'The actual blue lamp must be visible'
dilated=np.zeros_like(core)
for dy in range(-12,13):
 for dx in range(-12,13):
  if dx*dx+dy*dy<=144:dilated|=np.roll(np.roll(core,dy,0),dx,1)
annulus=dilated&~core
halo=float(np.maximum(y-x,0)[annulus].mean());assert halo>.2,halo
result=dict(fixed_camera_effects=rows,transparent_viewmodel=alpha,world_lamp_halo_mean_gain=halo)
(p/'pixel-comparison.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
hip=rgb('50-flare-hip-fixed');ads=rgb('51-flare-ads-fixed');none=rgb('52-flare-none-fixed')
h=hip-none;a=ads-none
mask=(h>8)&(hip<245)&(none<180)
ratio=float(a[mask].sum()/h[mask].sum());assert .20<ratio<.30,ratio
result['ads_flare_measured_ratio']=ratio
(p/'pixel-comparison.json').write_text(json.dumps(result,indent=2));print('ADS pixel ratio',ratio)
