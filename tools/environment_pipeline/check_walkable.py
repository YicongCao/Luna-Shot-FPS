import bpy,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
asset,stage=sys.argv[sys.argv.index('--')+1:];root=Path(__file__).resolve().parents[2];out=root/'art_source/environment/pipeline-v1'/asset/('02-high' if stage=='high' else '04-low')
bpy.ops.wm.open_mainfile(filepath=str(out/f'{asset}-{stage}.blend'))
verts=[];faces=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 offset=len(verts);verts.extend([o.matrix_world@v.co for v in o.data.vertices]);faces.extend([[i+offset for i in p.vertices] for p in o.data.polygons])
tree=BVHTree.FromPolygons(verts,faces);checks=[]
ys=[-3.8,-2,0,2,3.8] if asset=='C' else [-5.8,-4,-2,0,1.8,2.2,4,5.8]
for x in [-1.4,0,1.4]:
 for y in ys:
  expected=2.4 if asset=='C' or y>=2 else (y+6)*.3
  hit=tree.ray_cast(Vector((x,y,4)),Vector((0,0,-1)))
  err=abs(hit[0].z-expected) if hit[0] is not None else 999
  checks.append(dict(x=x,y=y,expected=expected,error=err,passed=err<.05))
if asset=='C':
 for x in [-1.4,0,1.4]:
  hit=tree.ray_cast(Vector((x,0,.05)),Vector((0,0,1)))
  checks.append(dict(check='underpass',x=x,ceiling=hit[0].z if hit[0] is not None else None,passed=hit[0] is not None and hit[0].z>=2.2))
report={'asset':asset,'stage':stage,'checks':checks,'failures':sum(not c['passed'] for c in checks)};(out/'walkable-check.json').write_text(json.dumps(report,indent=2));print('WALKABLE_CHECK',json.dumps(report))
if report['failures']:raise RuntimeError('Visual surface differs from approved walkable collision')
