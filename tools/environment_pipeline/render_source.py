import bpy,sys
from pathlib import Path
from mathutils import Vector
asset,stage=sys.argv[sys.argv.index('--')+1:];root=Path(__file__).resolve().parents[2];out=root/'art_source/environment/pipeline-v1'/asset/('02-high' if stage=='high' else '04-low')
bpy.ops.wm.open_mainfile(filepath=str(out/f'{asset}-{stage}.blend'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];pts=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)]);center=(lo+hi)*.5;size=max(hi-lo)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.world.color=(.13,.15,.18);sh=scene.display.shading;sh.light='STUDIO';sh.color_type='MATERIAL';sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH';sh.background_type='WORLD'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=size*1.5
for title,direction in [('front',(1,-1,.7)),('back',(-1,1,.7)),('side',(1,0,.15)),('top',(0,-.1,1))]:
 cam.location=center+Vector(direction)*size*2;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(title+'.png'));bpy.ops.render.render(write_still=True)
