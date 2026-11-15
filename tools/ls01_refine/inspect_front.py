import bpy,numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[2];bpy.ops.wm.open_mainfile(filepath=str(R/'art_source/weapons/lc01/industrial-wear-v1/04-low/lc01-low.blend'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];vs=[];fs=[]
for o in obs:
 offset=len(vs);vs.extend([o.matrix_world@v.co for v in o.data.vertices]);fs.extend([tuple(offset+i for i in f.vertices) for f in o.data.polygons])
tree=BVHTree.FromPolygons(vs,fs,all_triangles=True);ys=np.linspace(.40,.59,300);zs=np.linspace(-.045,.135,280);data=np.full((len(zs),len(ys)),np.nan)
for j,z in enumerate(zs):
 for i,y in enumerate(ys):
  hit=tree.ray_cast(Vector((.09,y,z)),Vector((-1,0,0)),.08)
  if hit[0] is not None:data[j,i]=hit[0].x
np.savez_compressed(R/'docs/validation/ls01-refine-v1/front-depth.npz',depth=data,y=ys,z=zs)
