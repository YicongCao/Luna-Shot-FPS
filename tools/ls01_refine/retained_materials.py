from pathlib import Path
from PIL import Image
import numpy as np,json,shutil
R=Path(__file__).resolve().parents[2];O=R/'art_source/weapons/lc01/ls01-refine-v1';D=R/'assets/weapons/lc01/ls01_v1/retained';D.mkdir(exist_ok=True)
assert not (D.parent/'APPROVED').exists(),'Active runtime protected; use a fresh candidate runtime path'
f=np.load(O/'retained-coordinates.npz');p=f['position'];n=f['normal'];cover=f['coverage'];N=2048
# Blender raster is bottom-up; external PNGs are top-down.
classes=np.load(R/'art_source/weapons/lc01/pipeline-v2/07-final/material-masks.npz')['classes']
def pic(path):return np.flipud(np.asarray(Image.open(path).convert('RGB')).astype(float)/255)
old=O/'00-baseline/lc01';bc=pic(old/'BaseColor.png');orm=pic(old/'ORM.png')
def sample(name,scale):
 im=np.asarray(Image.open(O/'01-imagegen'/f'{name}.png').convert('L')).astype(float)/255;h,w=im.shape
 # Blend all projections smoothly; this changes masks, never tangent normals.
 weight=np.abs(n)**4;weight/=np.maximum(weight.sum(-1,keepdims=True),1e-5);out=np.zeros((N,N))
 for axis,(a,b) in enumerate([(1,2),(0,2),(0,1)]):
  u=np.mod(p[:,:,a]*scale+.317,1);v=np.mod(p[:,:,b]*scale+.173,1);out+=im[(v*(h-1)).astype(int),(u*(w-1)).astype(int)]*weight[:,:,axis]
 return out
oil=sample('oil',4.7);wear=sample('wear',7.)
# Existing normal detail identifies localized high curvature, rather than UV-island boundaries.
baked=pic(R/'art_source/weapons/lc01/industrial-wear-v1/05-bake/NormalGL.png');curv=np.clip((np.linalg.norm(baked[:,:,:2]-.5,axis=-1)-.18)*4,0,1)
variation=(np.sin(p[:,:,1]*91+p[:,:,2]*37)+np.sin(p[:,:,2]*173+p[:,:,0]*53))*.5
exposed=np.clip(curv*np.clip(variation+.15,0,1)*.65+wear*.7,0,1)
for cls,col,rough,metal in [(1,(.79,.77,.70),.48,0),(2,(.85,.36,.12),.40,0),(3,(.31,.36,.41),.44,1),(4,(.09,.11,.13),.82,0)]:
 mask=(classes==cls)&cover
 color=np.array(col)[None,None,:]*(1-.15*oil[:,:,None]);r=rough+.055*variation-(.12 if cls==3 else .23)*oil;m=np.full((N,N),float(metal))
 if cls in [1,2]:
  color=color*(1-exposed[:,:,None])+np.array([.56,.60,.63])*exposed[:,:,None];m=exposed
 bc[mask]=color[mask];orm[:,:,1][mask]=np.clip(r[mask],.12,.92);orm[:,:,2][mask]=m[mask]
# Local coating-free front-shroud bolt seats (old geometry retained).
for side in [-1,1]:
 for y,z in [(.445,.106),(.554,.090),(.560,.008)]:
  distance=np.sqrt((p[:,:,1]-y)**2+(p[:,:,2]-z)**2);mask=(distance<.0035)&(side*p[:,:,0]>.040)&cover
  bc[mask]=(.56,.60,.63);orm[:,:,1][mask]=.28;orm[:,:,2][mask]=1
# Retained normals come from genuine pre-micro high-to-low bake, not axis-projected image noise.
normal=Image.open(R/'art_source/weapons/lc01/industrial-wear-v1/05-bake/NormalGL.png');normal.save(D/'NormalGL.png')
shutil.copy2(old/'Emission.png',D/'Emission.png')
# Dilate within the original atlas gutters. Unused regions are not sampled by retained meshes.
filled=cover.copy()
for i in range(16):
 prev=filled.copy()
 for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
  valid=np.roll(prev,(dy,dx),(0,1))&~filled
  if dy==1:valid[0]=False
  if dy==-1:valid[-1]=False
  if dx==1:valid[:,0]=False
  if dx==-1:valid[:,-1]=False
  for ar in [bc,orm]:ar[valid]=np.roll(ar,(dy,dx),(0,1))[valid]
  filled|=valid
for name,ar in [('BaseColor',bc),('ORM',orm),('AO',orm[:,:,0]),('Roughness',orm[:,:,1]),('Metallic',orm[:,:,2])]:Image.fromarray(np.uint8(np.clip(np.flipud(ar)*255,0,255))).save(D/(name+'.png'))
(O/'retained-material-report.json').write_text(json.dumps({'preserved_uv':True,'normal_source':'industrial-wear-v1/05-bake/NormalGL.png','masks':'original MaterialID + fixed low source position + smooth triplanar image masks + normal-derived curvature proxy','limitation':'normal-derived curvature is a proxy for retained generated geometry, not new geometric curvature bake','retained_pixels':int(cover.sum())},indent=2))
