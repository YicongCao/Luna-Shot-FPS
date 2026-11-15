"""Imagegen microheight -> object-space derivatives -> existing tangent normal atlas.
No UV edits. RNM composition retains the original high-to-low normal field.
"""
import bpy,numpy as np,json,shutil,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2];O=R/'art_source/industrial-wear-v1/06-imagegen';kind=sys.argv[-1]
D=R/'assets/weapons/lc01';blend=R/'art_source/weapons/lc01/industrial-wear-v1/04-low/lc01-low.blend'
if kind=='Kit':D=D/'field_kit';blend=R/'art_source/industrial-wear-v1/Kit/02-low/A-low.blend'
B=O/kind;B.mkdir(exist_ok=True)
for name in ['NormalGL','ORM','BaseColor']:
 if not (B/(name+'-before.png')).exists():shutil.copy2(D/(name+'.png'),B/(name+'-before.png'))
bpy.ops.wm.open_mainfile(filepath=str(blend))
def read(path):
 im=bpy.data.images.load(str(path),check_existing=False);im.colorspace_settings.name='Non-Color';w,h=im.size;a=np.empty(w*h*4,np.float32);im.pixels.foreach_get(a);return a.reshape(h,w,4)
h=read(O/'source-height.png')[:,:,:3].mean(2)
# Treat imagegen as a visual source, not calibrated measured height. Remove large-scale bias.
blur=h.copy()
for step in [1,2,4,8,16,32]:blur=(blur+np.roll(blur,step,0)+np.roll(blur,-step,0)+np.roll(blur,step,1)+np.roll(blur,-step,1))/5
h=(h-blur);h=np.clip(h/(np.std(h)*4+1e-6),-.75,.75)
# Fade outer 3% to a common flat boundary: generation alone is not proof of seamlessness.
H,W=h.shape;fy=np.minimum(np.arange(H),np.arange(H)[::-1])/(H*.03);fx=np.minimum(np.arange(W),np.arange(W)[::-1])/(W*.03);fade=np.minimum(np.clip(fy,0,1)[:,None],np.clip(fx,0,1)[None,:]);h*=fade
h=np.where(h<-.22,h+.22,np.where(h>.32,(h-.32)*.3,0))
period=.16;amplitude=.000045
hx=(np.roll(h,-1,1)-np.roll(h,1,1))*.5*W/period*amplitude;hy=(np.roll(h,-1,0)-np.roll(h,1,0))*.5*H/period*amplitude
normal=read(B/'NormalGL-before.png');orm=read(B/'ORM-before.png');base=read(B/'BaseColor-before.png');N=normal.shape[0];coverage=np.zeros((N,N),bool);changed=0
classes=None
if kind!='Kit':classes=np.load(R/'art_source/weapons/lc01/pipeline-v2/07-final/material-masks.npz')['classes']
def sample(a,u,v):
 x=np.mod(u/period,1)*(W-1);y=np.mod(v/period,1)*(H-1);ix=x.astype(int);iy=y.astype(int);fx=x-ix;fy=y-iy
 return a[iy,ix]*(1-fx)*(1-fy)+a[iy,(ix+1)%W]*fx*(1-fy)+a[(iy+1)%H,ix]*(1-fx)*fy+a[(iy+1)%H,(ix+1)%W]*fx*fy
for ob in [o for o in bpy.context.scene.objects if o.type=='MESH']:
 uv=ob.data.uv_layers.active
 for f in ob.data.polygons:
  pos=np.array([ob.data.vertices[i].co[:] for i in f.vertices]);tex=np.array([uv.data[i].uv[:] for i in f.loop_indices]);screen=tex*N-.5
  a,b,c=screen;den=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
  if abs(den)<1e-8:continue
  x0,y0=np.maximum(0,np.floor(screen.min(0)).astype(int));x1,y1=np.minimum(N-1,np.ceil(screen.max(0)).astype(int))
  if x0>x1 or y0>y1:continue
  xx,yy=np.meshgrid(np.arange(x0,x1+1),np.arange(y0,y1+1));w1=((xx-a[0])*(c[1]-a[1])-(yy-a[1])*(c[0]-a[0]))/den;w2=((b[0]-a[0])*(yy-a[1])-(b[1]-a[1])*(xx-a[0]))/den;w0=1-w1-w2;mask=(w0>=0)&(w1>=0)&(w2>=0);x=xx[mask];y=yy[mask]
  if not len(x):continue
  weights=np.stack([w0[mask],w1[mask],w2[mask]],1);p=weights@pos;coverage[y,x]=True
  enabled=np.isin(classes[y,x],[1,2,3]) if classes is not None else (base[y,x,:3].mean(1)>.065)
  if not enabled.any():continue
  x=x[enabled];y=y[enabled];p=p[enabled];weights=weights[enabled]
  e1=pos[1]-pos[0];e2=pos[2]-pos[0];du1=tex[1]-tex[0];du2=tex[2]-tex[0];det=du1[0]*du2[1]-du1[1]*du2[0]
  dpdu=(e1*du2[1]-e2*du1[1])/det;dpdv=(-e1*du2[0]+e2*du1[0])/det
  n=np.array(f.normal);T=dpdu-n*np.dot(n,dpdu);T/=max(np.linalg.norm(T),1e-8);BT=np.cross(n,T);BT*=1 if np.dot(BT,dpdv)>0 else -1
  axis=int(np.argmax(abs(n)));axes=[j for j in range(3) if j!=axis];u=p[:,axes[0]];v=p[:,axes[1]]
  gx=sample(hx,u,v);gy=sample(hy,u,v);detail=np.stack([-(gx*T[axes[0]]+gy*T[axes[1]]),-(gx*BT[axes[0]]+gy*BT[axes[1]]),np.ones(len(x))],1);detail/=np.linalg.norm(detail,axis=1)[:,None]
  n1=normal[y,x,:3]*2-1;t=n1+np.array([0,0,1]);u2=detail*np.array([-1,-1,1]);out=t*(t*u2).sum(1)[:,None]/np.maximum(t[:,2,None],.01)-u2;out/=np.maximum(np.linalg.norm(out,axis=1)[:,None],1e-8);normal[y,x,:3]=out*.5+.5
  height=sample(h,u,v);orm[y,x,1]=np.clip(orm[y,x,1]+np.clip(-height*.10,-.06,.15),.15,.95)
  base[y,x,:3]*=np.clip(1+height[:,None]*.16,.86,1.05);changed+=len(x)
filled=coverage.copy()
for _ in range(8):
 old=filled.copy()
 for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
  eligible=np.roll(old,(dy,dx),(0,1))&~filled
  if dy==1:eligible[0]=False
  if dy==-1:eligible[-1]=False
  if dx==1:eligible[:,0]=False
  if dx==-1:eligible[:,-1]=False
  for ar in [normal,orm,base]:ar[eligible]=np.roll(ar,(dy,dx),(0,1))[eligible]
  filled|=eligible
for name,ar in [('NormalGL',normal),('ORM',orm),('BaseColor',base)]:
 im=bpy.data.images.new(name,N,N,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(ar.ravel());im.filepath_raw=str(B/(name+'-after.png'));im.file_format='PNG';im.save();shutil.copy2(B/(name+'-after.png'),D/(name+'.png'))
(B/'report.json').write_text(json.dumps({'source':'imagegen source-height.png','amplitude_m':amplitude,'tile_period_m':period,'pixels_affected':changed,'UV_changed':False,'triangles_added':0,'normal_composition':'RNM','excluded':'rubber/emissive on main rifle; dark glass on kit','seam_treatment':'3 percent fade-to-zero and 8px atlas padding'},indent=2));print('MICRO_SURFACE_COMPLETE',kind,changed)
