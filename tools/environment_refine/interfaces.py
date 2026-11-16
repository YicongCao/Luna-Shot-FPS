"""Probe the authored low geometry, independent of unchanged gameplay collisions."""
import bpy,json,sys,argparse
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
p=argparse.ArgumentParser();p.add_argument('--asset',required=True);p.add_argument('--out');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);R=Path(__file__).resolve().parents[2];O=Path(a.out or R/'art_source/environment/refine-v2'/a.asset);m=json.loads((O/'manifest.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(O/'02-geometry/paired.blend'))
v=[];f=[]
for pair in m['pairs']:
 o=bpy.data.objects[pair['low']];offset=len(v);v.extend(o.matrix_world@x.co for x in o.data.vertices);f.extend(tuple(offset+i for i in p.vertices) for p in o.data.polygons)
bvh=BVHTree.FromPolygons(v,f);checks=[]
def check(name,passed,detail):checks.append({'check':name,'passed':bool(passed),'detail':detail})
if a.asset in ['C','D']:
 for x in [-1.35,-.45,.45,1.35]:
  for y in ([-3.37,-2.37,-1.37,-.37,.37,1.37,2.37,3.37] if a.asset=='C' else [-5.37,-4.37,-3.37,-2.37,-1.37,-.37,.37,1.37,2.37,3.37,4.37,5.37]):
   hit=bvh.ray_cast(Vector((x,y,10)),Vector((0,0,-1)))[0];expected=2.4 if a.asset=='C' or y>=2 else (y+6)*.3
   check('walk_height',hit is not None and abs(hit.z-expected)<.006,{'x':x,'y':y,'expected':expected,'actual':None if hit is None else hit.z})
 if a.asset=='C':
  for x in [-1.49,0,1.49]:
   for y in [-3.5,0,3.5]:
    hit=bvh.ray_cast(Vector((x,y,.01)),Vector((0,0,1)))[0]
    check('underbridge_3m_width_2_2m_height',hit is None or hit.z>=2.2,{'x':x,'y':y,'ceiling':None if hit is None else hit.z})
if a.asset=='E':
 for axis in [0,1]:
  clear=0;total=0
  for z in [2.2,2.6,3,4.2,4.6,5,6.2,6.6,7,8.2]:
   for u in [-.4,-.2,0,.2,.4]:
    origin=Vector((-2,u,z) if axis==0 else (u,-2,z));direction=Vector((1,0,0) if axis==0 else (0,1,0));total+=1
    if bvh.ray_cast(origin,direction)[0] is None:clear+=1
  check('open_lattice_axis_'+str(axis),clear/total>=.5,{'clear':clear,'samples':total})
D=R/'docs/validation/environment-refine-v2'/a.asset;D.mkdir(parents=True,exist_ok=True);fail=sum(not c['passed'] for c in checks);(D/'interfaces.json').write_text(json.dumps({'checks':checks,'failures':fail},indent=2));print('ENV_INTERFACES',a.asset,len(checks),fail);assert fail==0
