import bpy,json,math,bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]; BASE=ROOT/'art_source/weapons/lc01/pipeline-v1';OUT=BASE/'04-low';OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(BASE/'03-tripo-low/model.glb'))
report=[]
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 pts=[obj.matrix_world@Vector(c) for c in obj.bound_box];uv=obj.data.uv_layers.active
 report.append({'name':obj.name,'vertices':len(obj.data.vertices),'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)],'uv_loops':len(uv.data) if uv else 0,'materials':[m.name if m else '' for m in obj.data.materials]})
print(json.dumps(report,indent=2));(OUT/'raw-low-inspection.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lc01-low-import.blend'))
print('LOW_INSPECTION_COMPLETE')
