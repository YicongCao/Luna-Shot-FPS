"""Repair reviewed exterior winding without changing topology/UV, preserving v1 evidence."""
import bpy,bmesh,json,numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];SOURCE=ROOT/'art_source/weapons/lc01/pipeline-v1';OUT=ROOT/'art_source/weapons/lc01/pipeline-v2';OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
# Explicit reviewed exterior sides. Signed volume alone is invalid for these open meshes:
# T09 has negative signed volume but correctly outward side normals, and must NOT flip.
flips={'high':{0,2,7,8,12,14,15},'low':{2,8,12,14,15}}
report={'reason':'Backface culling exposed inverted exterior faces; no alpha transparency was enabled.','stages':{}}
def side_agreement(o):
 coords=np.array([v.co[:] for v in o.data.vertices]);ids=np.array([f.vertices[:] for f in o.data.polygons]);centers=coords[ids].mean(1);normals=np.array([f.normal[:] for f in o.data.polygons]);mask=np.abs(centers[:,0])>np.max(np.abs(coords[:,0]))*.75
 return float(np.mean(np.sign(centers[mask,0])*normals[mask,0]))
for stage,folder in [('high','02-high'),('low','04-low')]:
 dest=OUT/folder;dest.mkdir(exist_ok=True)
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE/folder/f'lc01-{stage}.blend'))
 rows=[]
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  idx=int(o.name[1:3]);before=side_agreement(o)
  if idx in flips[stage]:
   bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
   if stage=='low':
    o.data.normals_split_custom_set([(0,0,0)]*len(o.data.loops))
    bpy.context.view_layer.objects.active=o
    wn=o.modifiers.new('RepairedWeightedNormals','WEIGHTED_NORMAL');wn.keep_sharp=True;wn.weight=50;bpy.ops.object.modifier_apply(modifier=wn.name)
  after=side_agreement(o)
  assert after>0,(o.name,after)
  rows.append({'part':o.name,'faces':len(o.data.polygons),'flipped':idx in flips[stage],'exterior_side_normal_before':before,'exterior_side_normal_after':after})
 bpy.ops.wm.save_as_mainfile(filepath=str(dest/f'lc01-{stage}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(dest/f'lc01-{stage}.glb'),export_format='GLB',export_yup=True,export_extras=True)
 report['stages'][stage]=rows
# Reuse already paid texture input as a local, explicit reference.
remote=OUT/'06-tripo-pbr'
if not remote.exists():remote.symlink_to('../pipeline-v1/06-tripo-pbr',target_is_directory=True)
(OUT/'07-final').mkdir(exist_ok=True)
(OUT/'orientation-repair.json').write_text(json.dumps(report,indent=2));print('ORIENTATION_REPAIR_COMPLETE')
