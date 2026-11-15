"""Re-layer retained atlas without changing geometry/UV. Keep verified ML01 baked normals.
Material ID is inherited; coordinates and curvature/contact masks are reconstructed from fixed lows.
"""
import bpy,numpy as np,json
from pathlib import Path
R=Path(__file__).resolve().parents[2];O=R/'art_source/weapons/lc01/ls01-refine-v1';N=2048
bpy.ops.wm.open_mainfile(filepath=str(R/'art_source/weapons/lc01/industrial-wear-v1/04-low/lc01-low.blend'))
pos=np.zeros((N,N,3),np.float32);normal=np.zeros_like(pos);coverage=np.zeros((N,N),bool);edge=np.zeros((N,N),np.float32)
replace=json.loads((O/'manifest.json').read_text())['replaced_prefixes']
for ob in bpy.context.scene.objects:
 if ob.type!='MESH' or any(ob.name.startswith(p) for p in replace):continue
 for f in ob.data.polygons:
  p=np.array([ob.matrix_world@ob.data.vertices[i].co for i in f.vertices]);uv=np.array([ob.data.uv_layers.active.data[i].uv for i in f.loop_indices]);s=uv*N-.5
  mi=np.maximum(np.floor(s.min(0)).astype(int),0);ma=np.minimum(np.ceil(s.max(0)).astype(int),N-1)
  xx,yy=np.meshgrid(np.arange(mi[0],ma[0]+1),np.arange(mi[1],ma[1]+1));a,b,c=s;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
  if abs(den)<1e-8:continue
  w0=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den;w1=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den;w2=1-w0-w1;inside=(w0>=0)&(w1>=0)&(w2>=0);x=xx[inside];y=yy[inside];w=np.stack([w0[inside],w1[inside],w2[inside]],-1)
  pos[y,x]=w@p;normal[y,x]=f.normal[:];coverage[y,x]=True
np.savez_compressed(O/'retained-coordinates.npz',position=pos,normal=normal,coverage=coverage)
print('RETAINED_COORDS',coverage.sum())
