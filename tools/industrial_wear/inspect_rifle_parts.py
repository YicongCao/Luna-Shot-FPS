import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(R/'art_source/weapons/lc01/pipeline-v2/04-low/lc01-low.blend'))
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  p=[v.co for v in o.data.vertices]
  print('PART',o.name,[(round(min(v[i] for v in p),4),round(max(v[i] for v in p),4)) for i in range(3)])
