"""Authored mechanical detail on cleaned dense geometry, before retopology."""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];asset=sys.argv[-1];OUT=ROOT/'art_source/environment/pipeline-v1'/asset/'02-high'
bpy.ops.wm.open_mainfile(filepath=str(OUT/f'{asset}-high.blend'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];details=[]
def cylinder(pos,r,h,rot=(0,0,0),name='Pipe'):
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=h,location=pos,rotation=rot)
 o=bpy.context.object;o.name=name;mod=o.modifiers.new('MachinedBevel','BEVEL');mod.width=min(.008,r*.15);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name);details.append(o)
if asset in ['B1','B2']:
 for x in [-1.12,1.12]:
  cylinder((x,1.32,3),.065,4.8,name='CoolantRiser')
  for z in [1,1.85,2.7,3.55,4.4,5.25]:cylinder((x,1.32,z),.10,.09,name='PipeCollar')
 for x in [-1.45,1.45]:
  for y in [-1.45,1.45]:cylinder((x,y,5.98),.05,.04,name='FrameBolt')
elif asset=='E':
 base=next(o for o in obs if o.name=='E_P02_high')
 xs=[v.co.x for v in base.data.vertices];left=min(xs);right=max(xs)
 for v in base.data.vertices:v.co.x=(v.co.x-left)/(right-left)*2-1
 base.data.update();bpy.context.view_layer.update()
 for z in [1.6,3.6,5.6,7.6]:
  for x in [-.71,.71]:
   hit=bpy.context.scene.ray_cast(bpy.context.evaluated_depsgraph_get(),Vector((x,-5,z)),Vector((0,1,0)))
   if hit[0]:cylinder((x,hit[1].y-.009,z),.045,.025,(math.pi/2,0,0),'LatticeBolt')
if asset=='B2':
 bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,5.25))
 brace=bpy.context.object;brace.name='HeaderSupport';brace.scale=(.28,.28,1.0);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mod=brace.modifiers.new('Edge','BEVEL');mod.width=.015;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name);details.append(brace)
if details:
 receiver=max(obs,key=lambda o:o.dimensions.z)
 bpy.ops.object.select_all(action='DESELECT');receiver.select_set(True)
 for o in details:o.select_set(True)
 bpy.context.view_layer.objects.active=receiver;bpy.ops.object.join()
bpy.ops.object.select_all(action='SELECT');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{asset}-high.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/f'{asset}-high.glb'),export_format='GLB',export_materials='NONE',export_extras=True)
p=OUT/'geometry-report.json';d=json.loads(p.read_text());d['authored_details']='Coolant risers with bevelled collars and frame bolts' if asset.startswith('B') else 'Lattice connection bolts';d['triangles']=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs);p.write_text(json.dumps(d,indent=2))
print('REFINED',asset,d['triangles'])
