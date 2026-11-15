"""Restore exact walkable interfaces before retopology; retain useful generated structure."""
import bpy,json,sys,math,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];asset=sys.argv[-1];OUT=ROOT/'art_source/environment/pipeline-v1'/asset/'02-high'
bpy.ops.wm.open_mainfile(filepath=str(OUT/f'{asset}-high.blend'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];changes=[]
def box(pos,size,bevel=.01):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mod=o.modifiers.new('MachinedEdges','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name);return o
def join_into(receiver,details):
 bpy.ops.object.select_all(action='DESELECT');receiver.select_set(True)
 for o in details:o.select_set(True)
 bpy.context.view_layer.objects.active=receiver;bpy.ops.object.join()
if asset=='C':
 for o in obs:
  points=np.array([v.co[:] for v in o.data.vertices]);lo=points.min(0);hi=points.max(0);dims=hi-lo;center=(hi+lo)*.5
  if dims[0]>3 and dims[1]>6 and dims[2]<.6:
   old=o.data;new=box((0,0,2.325),(4,8,.15),.006)
   mw=new.matrix_world.copy()
   for v in new.data.vertices:v.co=mw@v.co
   o.data=new.data.copy();o.matrix_world=Matrix.Identity(4);bpy.data.objects.remove(new,do_unlink=True)
   ribs=[box((0,y,2.401),(3.35,.028,.008),.003) for y in np.linspace(-3.65,3.65,22)]
   join_into(o,ribs);changes.append({'part':o.name,'action':'Rebuilt exact 2.4 m deck and shallow anti-slip ribs; 2.25 m underside'})
  elif dims[2]>1.8 and hi[2]<2.4:
   cx=1.85 if center[0]>0 else -1.85;cy=3.6 if center[1]>0 else -3.6
   target_lo=np.array([cx-.125,cy-.15,0]);target_hi=np.array([cx+.125,cy+.15,2.25])
   points=(points-lo)/(hi-lo)*(target_hi-target_lo)+target_lo;o.data.vertices.foreach_set('co',points.astype(np.float32).ravel());o.data.update();changes.append({'part':o.name,'action':'Aligned original dense support to approved footprint and ground'})
  elif dims[1]>6:
   cx=1.85 if center[0]>0 else -1.85
   target_lo=np.array([cx-.11,-4,2.4]);target_hi=np.array([cx+.11,4,3.41])
   points=(points-lo)/(hi-lo)*(target_hi-target_lo)+target_lo;o.data.vertices.foreach_set('co',points.astype(np.float32).ravel());o.data.update();changes.append({'part':o.name,'action':'Restored side guardrail bounds and open end ports'})
elif asset=='D':
 receiver=next(o for o in obs if o.name=='D_P00_high')
 angle=math.atan(.3)
 ramp=box((0,-2+.08*math.sin(angle),1.2-.08*math.cos(angle)),(4,math.sqrt(8**2+2.4**2),.16),.005)
 ramp.rotation_euler.x=angle
 landing=box((0,4,2.325),(4,4,.15),.005)
 mw=ramp.matrix_world.copy();bpy.context.view_layer.update();mw=ramp.matrix_world.copy()
 for v in ramp.data.vertices:v.co=mw@v.co
 receiver.data=ramp.data.copy();receiver.matrix_world=Matrix.Identity(4);bpy.data.objects.remove(ramp,do_unlink=True)
 ribs=[]
 for y in np.linspace(-5.7,5.7,36):
  z=min(2.4,(y+6)*.3)
  rib=box((0,y,z+.001),(3.35,.028,.006),.002)
  if y<2:rib.rotation_euler.x=angle
  ribs.append(rib)
 join_into(receiver,[landing]+ribs)
 changes.append({'part':receiver.name,'action':'Exact 8 m rise/2.4 m ramp and 4 m landing, bevels and 36 high-poly shallow tread ribs'})
 for o in obs:
  if o.name not in ['D_P06_high','D_P07_high']:continue
  points=np.array([v.co[:] for v in o.data.vertices]);lo=points.min(0);hi=points.max(0)
  points[:,2]=(points[:,2]-lo[2])/(hi[2]-lo[2])*2.25
  o.data.vertices.foreach_set('co',points.astype(np.float32).ravel());o.data.update()
  changes.append({'part':o.name,'action':'Grounded dense generated landing support, top 2.25 m'})
else:raise RuntimeError('Unsupported conformance asset')
bpy.ops.object.select_all(action='SELECT');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{asset}-high.blend'));bpy.ops.export_scene.gltf(filepath=str(OUT/f'{asset}-high.glb'),export_format='GLB',export_materials='NONE',export_extras=True)
(OUT/'conformance.json').write_text(json.dumps({'asset':asset,'changes':changes},indent=2))
p=OUT/'geometry-report.json';r=json.loads(p.read_text());r['triangles']=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in obs);r['conformance_changes']=changes;p.write_text(json.dumps(r,indent=2));print('CONFORMED',asset,r['triangles'])
