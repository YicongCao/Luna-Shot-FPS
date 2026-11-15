"""Analyze actual Godot screenshots; never synthesize the reported render results."""
from PIL import Image
import numpy as np,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/validation/rifle-pipeline-v2'
def load(n):return np.array(Image.open(OUT/(n+'.png')).convert('RGB')).astype(float)/255
final=load('01-hero-pbr');h,w=final.shape[:2]
roi=np.zeros((h,w),bool);roi[int(h*.2):int(h*.84),int(w*.15):int(w*.85)]=True
# exclude flat studio background, labels outside ROI
mask=roi&(final.max(2)>.12)
report={'method':'same camera and geometry; gun ROI excludes HUD and flat backdrop','comparisons':{}}
for name,other in [('baked_normal','02-hero-no-normal'),('material_response','03-hero-uniform-response'),('warm_rig','05-hero-warm'),('cool_rig','06-hero-cool')]:
 a=load(other);delta=np.abs(final-a).mean(2);report['comparisons'][name]={'mean_absolute_rgb_change':float(delta[mask].mean()),'fraction_over_2_percent':float(np.mean(delta[mask]>.02))}
 assert report['comparisons'][name]['fraction_over_2_percent']>.02, f'No visible response: {name}'
# Pixel data is encoded sRGB on disk. Recover linear values to test corrected color encoding.
p=ROOT/'art_source/weapons/lc01/pipeline-v2/07-final';classes=np.load(p/'material-masks.npz')['classes'][::-1]
base=np.array(Image.open(p/'textures/BaseColor.png')).astype(float)[:,:,:3]/255
linear=np.where(base<=.04045,base/12.92,((base+.055)/1.055)**2.4)
report['mean_linear_basecolor']={str(k):linear[classes==k].mean(0).tolist() for k in range(1,6)}
assert report['mean_linear_basecolor']['2'][1]>.09,'Orange color lost in encoding'
on=load('17-coils-on-right');off=load('18-coils-off-right')
energy_roi=(slice(int(h*.30),int(h*.85)),slice(int(w*.30),int(w*.80)))
delta=np.abs(on-off).mean(2)[energy_roi]
report['energy_on_off']={'mean_absolute_rgb_change':float(delta.mean()),'fraction_over_2_percent':float(np.mean(delta>.02))}
assert report['energy_on_off']['fraction_over_2_percent']>.1,'Energy effect not visibly different from albedo-only'
(OUT/'render-comparison.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
