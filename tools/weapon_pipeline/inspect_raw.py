import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art_source/weapons/lc01/pipeline-v1'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(BASE/'01-tripo-geometry/model.glb'))
report=[]
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 pts=[obj.matrix_world@Vector(c) for c in obj.bound_box]
 report.append({'name':obj.name,'vertices':len(obj.data.vertices),'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)],'materials':[m.name for m in obj.data.materials]})
print(json.dumps(report,indent=2))
(BASE/'raw-inspection.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'raw-import.blend'))
print('RAW_INSPECTION_COMPLETE')
