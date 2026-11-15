import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[2];O=R/'art_source/industrial-wear-v1/Kit'
for f in ['01-high','02-low','03-bake','04-final']:(O/f).mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(O.parent/'kit-whitebox.glb'))
objs=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
for o in objs:o.select_set(True)
bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();lo=bpy.context.object;lo.name='A_low';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Manufacture sub-millimetre chamfers before UV locking.
b=lo.modifiers.new('CrispManufacturedEdges','BEVEL');b.width=.00035;b.segments=1;b.limit_method='ANGLE';b.angle_limit=.65;bpy.ops.object.modifier_apply(modifier=b.name)
hi=lo.copy();hi.data=lo.data.copy();hi.name='A_high';bpy.context.collection.objects.link(hi)
bpy.context.view_layer.objects.active=hi;b=hi.modifiers.new('HighMicroBevel','BEVEL');b.width=.00010;b.segments=3;b.limit_method='ANGLE';b.angle_limit=.65;bpy.ops.object.modifier_apply(modifier=b.name)
lo.hide_render=True;lo.hide_viewport=True;bpy.ops.wm.save_as_mainfile(filepath=str(O/'01-high/A-high.blend'))
lo.hide_render=False;lo.hide_viewport=False;bpy.data.objects.remove(hi,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT');lo.select_set(True);bpy.context.view_layer.objects.active=lo
m=lo.modifiers.new('FixedTriangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.008);bpy.ops.uv.pack_islands(margin=.006);bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(O/'02-low/A-low.blend'));(O/'geometry.json').write_text(json.dumps({'triangles':len(lo.data.polygons),'source':'local precise rebuild of field-kit components; Tripo reference audited separately'},indent=2))
