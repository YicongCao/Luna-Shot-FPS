"""Run with Blender --background --python. Whitebox only; no UV/bakes/PBR claim."""
import bpy, json, math
from pathlib import Path
from mathutils import Matrix, Euler
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
collection=bpy.context.collection
collection.name='LC01_WHITEBOX_ONLY'
conversion=Matrix.Rotation(math.pi/2,4,'X')
materials={}
for name,value in [('Shell',.74),('Core',.28),('Grip',.12)]:
 m=bpy.data.materials.new('WB_'+name);m.diffuse_color=(value,value,value,1);materials[name]=m
parts=json.loads((ROOT/'docs/design/rifle-blockout-parts.json').read_text())
for p in parts:
 name=p['name'];dims=p['size']
 if name.startswith(('P11','P12')):
  # Blender cylinders are Z-axis; Godot CylinderMesh is Y-axis.
  bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=dims[0]/2,depth=dims[1])
  obj=bpy.context.object
  for vert in obj.data.vertices: vert.co=Matrix.Rotation(math.pi/2,3,'X')@vert.co
 else:
  bpy.ops.mesh.primitive_cube_add(size=1)
  obj=bpy.context.object
  for vert in obj.data.vertices:
   for i in range(3):vert.co[i]*=dims[i]
 obj.name=name
 obj.matrix_world=conversion @ Matrix.Translation(p['position']) @ Euler(p['rotation'],'XYZ').to_matrix().to_4x4()
 obj.data.materials.append(materials['Grip' if name.startswith(('P06','P08','P12')) else 'Core' if name.startswith(('P01','P07','P10','P11')) else 'Shell'])
 obj['stage']='WHITEBOX, NOT HIGH/LOW FINAL'
 obj['godot_part_id']=name[:3]
for name,position in {'MuzzleSocket':(0,.065,-.67),'SightRear':(0,.216,-.07),'SightFront':(0,.216,-.17),'GripR':(0,-.08,.015),'GripL':(0,-.035,-.43),'CellSocket':(0,-.04,-.15)}.items():
 obj=bpy.data.objects.new(name,None);collection.objects.link(obj);obj.matrix_world=conversion@Matrix.Translation(position);obj.empty_display_size=.025
bpy.context.scene.unit_settings.system='METRIC'
bpy.context.scene['NOTE']='Editable LC01 proxy, units m. Blender +Y forward converts to Godot -Z. No UV, high-poly, bake or PBR completed.'
out=ROOT/'art_source/weapons/lc01';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'lc01-whitebox.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'lc01-whitebox.glb'),export_format='GLB',export_yup=True,export_extras=True)
print('LC01_SOURCE_COMPLETE')
