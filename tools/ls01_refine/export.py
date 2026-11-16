"""Export exact low geometry, retain old parts and UVs; explicit named bindings."""
import bpy,json,sys,argparse,hashlib,struct
from pathlib import Path
R=Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--out',default=str(R/'art_source/weapons/lc01/ls01-refine-v1'));a.add_argument('--runtime',default=str(R/'assets/weapons/lc01/ls01_v1'));args=a.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
O=Path(args.out);D=Path(args.runtime);D.mkdir(parents=True,exist_ok=True)
assert not (D/'APPROVED').exists(),'Active validated runtime is protected: choose a new --runtime directory'
m=json.loads((O/'manifest.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(O/'02-geometry/paired.blend'))
keep={p['low'] for p in m['pairs']}
for ob in list(bpy.context.scene.objects):
 if ob.name not in keep:bpy.data.objects.remove(ob,do_unlink=True)
new=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.import_scene.gltf(filepath=str(O/'00-baseline/lc01/lc01.glb'))
old=[o for o in bpy.context.selected_objects if o.type=='MESH'];retained=[]
for ob in old:
 if any(ob.name.startswith(p) for p in m['replaced_prefixes']):bpy.data.objects.remove(ob,do_unlink=True)
 else:retained.append(ob)
# GLB import source parts are already in Blender basis, source units preserved.
bindings={};new_by_name={p['low']:p for p in m['pairs']}
for ob in new+retained:
 group=new_by_name[ob.name]['group'] if ob in new else 'retained';ob['atlas']=group
 # Stable Blender materials carry atlas identity; engine binds through manifest, not heuristics.
 mat=bpy.data.materials.get('Atlas_'+group) or bpy.data.materials.new('Atlas_'+group);mat.diffuse_color={'body':(.65,.55,.4,1),'kit':(.15,.22,.26,1),'retained':(.2,.2,.2,1)}[group]
 ob.data.materials.clear();ob.data.materials.append(mat)
 for p in ob.data.polygons:p.material_index=0
 bindings[ob.name.replace('.', '_')]={'atlas':group,'moving_cell':ob.name.startswith(('T04','T11','Cell_')),'retained':ob in retained}
# Reuse already baked Phillips prototypes on retained front-bracket seats.
# Translation only: tangent basis/UV stays identical; intentional shared UV is recorded.
from mathutils import Vector
if m.get('revision')!='ml09':
 for side in [-1,1]:
  for index,target in enumerate([(side*.046,.428,-.013),(side*.0525,.554,.034),(side*.0395,.545,.111),(side*.04,.532,.006)]):
   for suffix in ['', '_seat']:
    source=bpy.data.objects[f'Receiver_{side}_0{suffix}_low'];copy=source.copy();copy.data=source.data.copy();copy.name=f'FrontPhillips{side}_{index}{suffix}';bpy.context.collection.objects.link(copy)
    source_center=Vector((side*.0551,.015,.083));target_center=Vector(target)
    for v in copy.data.vertices:v.co=(v.co-source_center)*1.5+target_center
    new.append(copy);bindings[copy.name]={'atlas':'body','moving_cell':False,'retained':False}
 m['reused_fasteners']={'count':8,'instances':[{'name':f'FrontPhillips{side}_{index}','center':list(target),'normal':[side,0,0],'radius':.00375,'prototype':f'Receiver_{side}_0','scale':1.5,'intentional_shared_uv':True} for side in [-1,1] for index,target in enumerate([(side*.046,.428,-.013),(side*.0525,.554,.034),(side*.0395,.545,.111),(side*.04,.532,.006)])],'location':'front-shroud side depth survey; front-depth.npz','prototype':'Receiver ±1 0 head + seat','intentional_shared_uv':True,'uniform_scale':1.5,'normal_basis_preserved':True}
# Consolidate static parts by atlas and animation membership; source keeps per-part detail.
merged=[];new_bindings={}
for name,subset in [
 ('BodyRebuilt',[o for o in new if bindings[o.name.replace('.', '_')]['atlas']=='body' and not bindings[o.name.replace('.', '_')]['moving_cell']]),
 ('T04_CellAssembly',[o for o in new if o.name.startswith(('T04','Cell_'))]),
 ('T11_CellSide',[o for o in new if o.name.startswith('T11')]),
 ('IndustrialKit',[o for o in new if bindings[o.name.replace('.', '_')]['atlas']=='kit'])]:
 bpy.ops.object.select_all(action='DESELECT')
 for ob in subset:ob.select_set(True)
 bpy.context.view_layer.objects.active=subset[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=name
 # Material slots referencing the same atlas collapse to one surface.
 mat=ob.data.materials[0];ob.data.materials.clear();ob.data.materials.append(mat)
 for face in ob.data.polygons:face.material_index=0
 merged.append(ob);new_bindings[name]={'atlas':'kit' if name=='IndustrialKit' else 'body','moving_cell':name.startswith(('T04','T11')),'retained':False}
for ob in retained:new_bindings[ob.name.replace('.', '_')]=bindings[ob.name.replace('.', '_')]
bpy.ops.object.select_all(action='DESELECT')
for ob in merged+retained:ob.select_set(True)
bpy.context.view_layer.objects.active=merged[0]
bpy.ops.export_scene.gltf(filepath=str(D/'weapon.glb'),export_format='GLB',use_selection=True,export_materials='EXPORT',export_tangents=True,export_extras=True)
(D/'bindings.json').write_text(json.dumps(new_bindings,indent=2));m['runtime_triangles']=sum(len(o.data.polygons) for o in merged+retained);m['retained_parts']=[o.name for o in retained];m['runtime_meshes']=len(merged+retained);assert m['runtime_triangles']<=60000
(O/'manifest.json').write_text(json.dumps(m,indent=2));print('EXPORT_COMPLETE',m['runtime_triangles'],len(retained))

if (O/'screen.json').exists():
 import shutil
 shutil.copy2(O/'screen.json',D/'screen.json')
