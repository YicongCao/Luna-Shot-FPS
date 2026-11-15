import bpy,json
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2];O=R/'art_source/industrial-wear-v1/00-tripo'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(O/'model.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)]);center=(lo+hi)/2
print('TRIPO_BOUNDS',lo[:],hi[:],sum(len(o.data.polygons) for o in meshes))
s=bpy.context.scene;s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=1000;s.render.resolution_y=800;s.render.resolution_percentage=100;s.display.shading.light='STUDIO';s.display.shading.show_cavity=True;s.display.shading.cavity_type='BOTH'
bpy.ops.object.camera_add(location=center+Vector((1.5,-2,1.6))*max(hi-lo));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=max(hi-lo)*1.6;s.camera=cam;s.render.filepath=str(O/'inspection.png');bpy.ops.render.render(write_still=True)
(O/'inspection.json').write_text(json.dumps({'min':list(lo),'max':list(hi),'faces':sum(len(o.data.polygons) for o in meshes)},indent=2))
