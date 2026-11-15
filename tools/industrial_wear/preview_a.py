import bpy
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2];bpy.ops.wm.open_mainfile(filepath=str(R/'art_source/industrial-wear-v1/A/01-high/A-high.blend'));s=bpy.context.scene;s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=1000;s.render.resolution_y=800;s.render.resolution_percentage=100;s.display.shading.show_cavity=True;s.display.shading.cavity_type='BOTH';s.display.shading.color_type='MATERIAL'
bpy.ops.object.camera_add(location=(5,-7,6));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.6))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.6;s.camera=cam;s.render.filepath=str(R/'docs/validation/industrial-wear-v1/A-high-diagnostic.png');bpy.ops.render.render(write_still=True)
