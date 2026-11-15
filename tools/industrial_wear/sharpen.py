"""Constrained side-plane fit, preserving vertex/face/UV indexing, then rebake."""
import bpy,numpy as np,json,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[2];src=R/'art_source/weapons/lc01/pipeline-v2';out=R/'art_source/weapons/lc01/industrial-wear-v1';out.mkdir(exist_ok=True);(out/'.gdignore').touch();report=[]
for stage,folder in [('high','02-high'),('low','04-low')]:
 (out/folder).mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(src/folder/f'lc01-{stage}.blend'))
 for ob in [o for o in bpy.context.scene.objects if o.type=='MESH']:
  if not ob.name.startswith(('T03','T08')):continue
  uv=ob.data.uv_layers.active;before=np.array([v.uv[:] for v in uv.data]) if uv else None;index=[list(f.vertices) for f in ob.data.polygons]
  coords=np.array([v.co[:] for v in ob.data.vertices]);target=.054 if ob.name.startswith('T03') else .0375
  mask=(np.abs(coords[:,0])>target-.0015)&(np.abs(coords[:,0])<target+.0015)
  for i in np.where(mask)[0]:ob.data.vertices[int(i)].co.x=np.sign(coords[i,0])*target
  ob.data.update()
  if stage=='low':
   ob.data.normals_split_custom_set([(0,0,0)]*len(ob.data.loops));bpy.context.view_layer.objects.active=ob
   m=ob.modifiers.new('PlanarWeightedNormals','WEIGHTED_NORMAL');m.keep_sharp=True;m.weight=50;bpy.ops.object.modifier_apply(modifier=m.name)
  assert index==[list(f.vertices) for f in ob.data.polygons]
  if uv:assert np.array_equal(before,np.array([v.uv[:] for v in ob.data.uv_layers.active.data]))
  report.append({'stage':stage,'part':ob.name,'vertices_fitted':int(mask.sum()),'max_displacement_m':float(np.max(np.abs(np.abs(coords[mask,0])-target))) if mask.any() else 0,'topology_preserved':True,'uv_preserved':True})
 bpy.ops.wm.save_as_mainfile(filepath=str(out/folder/f'lc01-{stage}.blend'))
 if stage=='low':bpy.ops.export_scene.gltf(filepath=str(out/'lc01.glb'),export_format='GLB',export_materials='NONE',export_yup=True)
(out/'05-bake').mkdir(exist_ok=True);(out/'sharpen-report.json').write_text(json.dumps(report,indent=2))
