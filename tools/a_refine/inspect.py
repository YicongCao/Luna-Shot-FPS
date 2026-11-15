import bpy,json,numpy as np
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2];B=R/'art_source/environment/A-refine-v2'
bpy.ops.wm.open_mainfile(filepath=str(B/'02-low/A-low.blend'));o=bpy.data.objects['A_low'];uv=o.data.uv_layers.active
bad=sum(any(v<-.00001 or v>1.00001 for v in loop.uv) for loop in uv.data)
area_zero=0
for p in o.data.polygons:
 a,b,c=[Vector(uv.data[i].uv) for i in p.loop_indices];area_zero+=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-12
assert bad==0 and area_zero==0,(bad,area_zero)
(B/'uv-audit.json').write_text(json.dumps({'out_of_bounds':bad,'degenerate_uv_triangles':area_zero,'triangles':len(o.data.polygons)},indent=2))
s=bpy.context.scene;s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=1200;s.render.resolution_y=900;s.render.resolution_percentage=100
s.world.color=(.04,.05,.06);sh=s.display.shading;sh.light='STUDIO';sh.color_type='MATERIAL';sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH';sh.background_type='WORLD'
bpy.ops.object.camera_add();cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=5.4;center=Vector((0,0,.6))
for name,d in [('front',(1,-1,.8)),('back',(-1,1,.8))]:
 cam.location=center+Vector(d)*6;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(B/('design-'+name+'.png'));bpy.ops.render.render(write_still=True)
