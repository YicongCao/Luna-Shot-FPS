import bpy,json,hashlib,numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'art_source/weapons/lc01/pipeline-v1';OUT=BASE/'07-final';OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(BASE/'06-tripo-pbr/model.glb'))
report={'objects':[],'images':[],'materials':[]}
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':
  pts=[obj.matrix_world@Vector(c) for c in obj.bound_box]
  report['objects'].append({'name':obj.name,'verts':len(obj.data.vertices),'tris':sum(len(p.vertices)-2 for p in obj.data.polygons),'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)],'uv':len(obj.data.uv_layers.active.data) if obj.data.uv_layers.active else 0,'materials':[m.name for m in obj.data.materials]})
for mat in bpy.data.materials:
 if not mat.use_nodes:continue
 report['materials'].append({'name':mat.name,'nodes':[{'type':n.type,'name':n.name,'image':n.image.name if n.type=='TEX_IMAGE' and n.image else None} for n in mat.node_tree.nodes],'links':[[l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name] for l in mat.node_tree.links]})
for im in bpy.data.images:
 if im.type=='RENDER_RESULT':continue
 report['images'].append({'name':im.name,'size':list(im.size),'colorspace':im.colorspace_settings.name})
 im.filepath_raw=str(OUT/('tripo-'+im.name.replace('/','_')+'.png'));im.file_format='PNG';im.save()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'tripo-pbr-import.blend'))
(OUT/'pbr-inspection.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
