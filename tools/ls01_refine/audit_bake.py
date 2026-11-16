from pathlib import Path
from PIL import Image
import numpy as np,json
from paths import parse
args,R,O,D,REPORT=parse();report={};fail=[]
from bake_contract import source_digest
for group in ['body','kit']:
 contract=json.loads((O/'03-bake'/group/'contract.json').read_text())
 if contract['source_sha256']!=source_digest(O/'02-geometry/paired.blend'):fail.append(group+'_stale_source_contract')
 covered=np.flipud(np.load(O/(group+'-uv-coverage.npz'))['owners']>=0)
 # Erode strict raster mask to avoid filter / gutter boundaries in channel statistics.
 mask=covered.copy()
 for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:mask &= np.roll(covered,(dy,dx),(0,1))
 images={n:np.asarray(Image.open(D/group/(n+'.png')).convert('RGB').resize((2048,2048),Image.Resampling.NEAREST)).astype(float)/255 for n in ['BaseColor','ORM','NormalGL']}
 no=images['NormalGL']*2-1;length=np.linalg.norm(no,axis=-1);orm=images['ORM'];metal=orm[:,:,2];rough=orm[:,:,1]
 data={'runtime_size':Image.open(D/group/'NormalGL.png').size,'statistics_grid':2048,'sample_pixels':int(mask.sum()),'basecolor_zero_pixels':int(np.count_nonzero(mask&np.all(images['BaseColor']==0,axis=-1))),'normal_length_p01_p99':np.percentile(length[mask],[1,99]).tolist(),'metal_p05_p50_p95':np.percentile(metal[mask],[5,50,95]).tolist(),'rough_p05_p50_p95':np.percentile(rough[mask],[5,50,95]).tolist()}
 def scalar(name):return np.asarray(Image.open(O/'03-bake'/group/(name+'.png')).convert('L').resize((2048,2048),Image.Resampling.BILINEAR)).astype(float)/255
 ids=scalar('MaterialID');oil=scalar('OilMask');wear=scalar('WearMask');stats={}
 for label,value in [('paint_white',.1),('paint_orange',.2),('dark_coating',.3),('steel',.4),('copper',.5)]:
  region=mask&(abs(ids-value)<.012)
  if region.sum()<100 or (group=='body' and label=='copper'):continue
  oily=region&(oil>.25);dry=region&(oil<.03)
  stats[label]={'pixels':int(region.sum()),'roughness_p05_p50_p95':np.percentile(rough[region],[5,50,95]).tolist(),'metallic_p05_p50_p95':np.percentile(metal[region],[5,50,95]).tolist(),'oily_pixels':int(oily.sum()),'dry_pixels':int(dry.sum()),'oily_roughness_median':float(np.median(rough[oily])) if oily.any() else None,'dry_roughness_median':float(np.median(rough[dry])) if dry.any() else None,'exposed_pixels':int(np.count_nonzero(region&(wear>.7)))}
 data['material_statistics']=stats
 report[group]=data
 if data['basecolor_zero_pixels']>mask.sum()*.001:fail.append(group+'_missed_projection')
 if data['normal_length_p01_p99'][0]<.97 or data['normal_length_p01_p99'][1]>1.03:fail.append(group+'_normal_lengths')
 for name in ['NormalGL','AO','BaseColor','Roughness','Metallic','Curvature','EdgeMask','Position','WorldNormal','MaterialID','WearMask','OilMask']:
  path=O/'03-bake'/group/(name+'.png')
  if not path.exists() or Image.open(path).size!=(4096,4096):fail.append(group+'_'+name+'_master')
 if not (O/'03-bake'/group/'Position.exr').exists():fail.append(group+'_position_exr')
report['failures']=fail;(REPORT/'bake-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));assert not fail
