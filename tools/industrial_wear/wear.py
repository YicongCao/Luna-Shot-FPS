"""Object-space wear rasterized into the existing per-corner UVs, deterministic seed."""
import bpy,numpy as np,json,shutil,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2];kind=sys.argv[-1];N=2048
O=R/'art_source/industrial-wear-v1'/kind;O.mkdir(parents=True,exist_ok=True)
if kind=='LC01':
 src=R/'assets/weapons/lc01';baseline=O/'00-baseline';baseline.mkdir(exist_ok=True)
 for name in ['lc01.glb','BaseColor.png','NormalGL.png','ORM.png','Emission.png']:
  if not (baseline/name).exists():shutil.copy2(src/name,baseline/name)
 src=baseline;blend=R/'art_source/weapons/lc01/pipeline-v2/04-low/lc01-low.blend'
else:src=O/'04-final';blend=O/'02-low/A-low.blend'
bpy.ops.wm.open_mainfile(filepath=str(blend))
def array(name):
 im=bpy.data.images.load(str(src/(name+'.png')),check_existing=False);im.colorspace_settings.name='Non-Color';a=np.empty(N*N*4,np.float32);im.pixels.foreach_get(a);return a.reshape(N,N,4)
base=array('BaseColor');orm=array('ORM');coverage=np.zeros((N,N),bool);changed=0
for ob in [o for o in bpy.context.scene.objects if o.type=='MESH']:
 uv=ob.data.uv_layers.active
 for f in ob.data.polygons:
  assert len(f.vertices)==3
  pos=np.array([ob.data.vertices[i].co[:] for i in f.vertices]);tex=np.array([uv.data[i].uv[:] for i in f.loop_indices])*N-.5
  x0,y0=np.maximum(0,np.floor(tex.min(0)).astype(int));x1,y1=np.minimum(N-1,np.ceil(tex.max(0)).astype(int))
  if x0>x1 or y0>y1:continue
  xx,yy=np.meshgrid(np.arange(x0,x1+1),np.arange(y0,y1+1));a,b,c=tex;den=np.cross(b-a,c-a)
  if abs(den)<1e-8:continue
  w1=((xx-a[0])*(c[1]-a[1])-(yy-a[1])*(c[0]-a[0]))/den;w2=((b[0]-a[0])*(yy-a[1])-(b[1]-a[1])*(xx-a[0]))/den;w0=1-w1-w2
  mask=(w0>=0)&(w1>=0)&(w2>=0);x=xx[mask];y=yy[mask]
  if not len(x):continue
  p=np.stack([w0[mask],w1[mask],w2[mask]],1)@pos;coverage[y,x]=True
  axis=int(np.argmax(np.abs(f.normal)));axes=[j for j in range(3) if j!=axis];u=p[:,axes[0]];v=p[:,axes[1]]
  scale=1 if kind=='A' else 8
  q=(u+.37*v)*scale;r=(v-.12*u)*scale
  cx=np.floor(q*3);cy=np.floor(r*38);rnd=np.mod(np.sin(cx*127.1+cy*311.7+41.3)*43758.5453,1)
  lx=np.mod(q*3,1);ly=np.mod(r*38,1)
  scratches=(rnd>.89)&(lx>.12)&(lx<.82)&(ly<.055)
  # Sparse paired dark gouges and exposed/coating-polished lips; no uniform white edge outline.
  shallow=(rnd>.85)&(lx>.25)&(lx<.65)&(ly>.065)&(ly<.085)
  emissive=(base[y,x,2]>base[y,x,0]*1.8)&(base[y,x,1]>base[y,x,0]*1.5)
  scratches &= ~emissive;shallow &= ~emissive
  if kind=='A':
   localx=np.mod(p[:,0]+1.829,1.11);localy=np.mod(p[:,1]+1.78,1.78)
   contact=(np.minimum(localx,1.11-localx)<.19)|(np.minimum(localy,1.78-localy)<.22)
   keep=(p[:,2]<1.16)|contact
   scratches &= keep;shallow &= keep
   service_strokes=(p[:,2]>1.17)&(localx>.10)&(localx<.58)&(np.minimum.reduce([abs(localy-.18-localx*.26),abs(localy-.205-localx*.26),abs(localy-1.56+localx*.16)])<.004)
   scratches |= service_strokes
  bc=base[y,x,:3].copy();rough=orm[y,x,1].copy()
  bc[scratches]*=.72;rough[scratches]=.76
  bc[shallow]=bc[shallow]*.65+np.array([.45,.46,.46])*.35;rough[shallow]=.34
  if kind=='A':
   # Dirt follows the base, not arbitrary UV chart seams.
   caution=(p[:,0]>1.43)&(p[:,1]<-1.25)&(p[:,1]>-1.65)&(p[:,2]>.80)&(p[:,2]<.96)
   band=np.mod((p[:,1]+p[:,2]) * 22,1)>.5
   bc[caution&band]=(.94,.39,.045);bc[caution&~band]=(.02,.03,.04)
   dust=np.clip((.33-p[:,2])/.33,0,1)*.25
   bc=bc*(1-dust[:,None])+np.array([.24,.23,.22])*dust[:,None];rough=np.clip(rough+dust,0,1)
  else:
   if ob.name.startswith('T03'):
    caution=(abs(p[:,0])>.044)&(p[:,1]>.12)&(p[:,1]<.25)&(p[:,2]>.079)&(p[:,2]<.105)
    orange=np.mod((p[:,1]+p[:,2]*.85)*75,1)>.5
    bc[caution&orange]=(.92,.36,.045);bc[caution&~orange]=(.025,.032,.04);bc[caution&scratches]*=.55;rough[caution]=.61
  base[y,x,:3]=bc;orm[y,x,1]=rough;changed+=int(scratches.sum()+shallow.sum())
# Padding stays coherent at UV seams and mip levels.
filled=coverage.copy()
for _ in range(8):
 old=filled.copy()
 for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
  eligible=np.roll(old,(dy,dx),(0,1))&~filled
  if dy==1:eligible[0]=False
  if dy==-1:eligible[-1]=False
  if dx==1:eligible[:,0]=False
  if dx==-1:eligible[:,-1]=False
  for ar in [base,orm]:ar[eligible]=np.roll(ar,(dy,dx),(0,1))[eligible]
  filled|=eligible
out=O/'05-wear';out.mkdir(exist_ok=True)
for name,ar in [('BaseColor',base),('ORM',orm)]:
 im=bpy.data.images.new(name,N,N,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(ar.ravel());im.filepath_raw=str(out/(name+'.png'));im.file_format='PNG';im.save()
for name in ['NormalGL','Emission']:shutil.copy2(src/(name+'.png'),out/(name+'.png'))
(out/'report.json').write_text(json.dumps({'source':str(src),'scratch_pixels':changed,'seed':41.3,'UV_modified':False,'geometry_modified':False},indent=2));print('WEAR_COMPLETE',kind,changed)
