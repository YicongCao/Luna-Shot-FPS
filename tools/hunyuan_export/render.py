"""Export consistent PBR reference views from the archived Tripo HIGH mesh.
No mesh editing, no image generation, no baked asset writes.
"""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[2];D=R/'docs/art/hunyuan-rifle-input';D.mkdir(parents=True,exist_ok=True)
src=R/'art_source/weapons/lc01/tripo-rebuild-v3/01-high-pbr/model.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(src))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.context.view_layer.update()
pts=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
scale=.905/(hi.y-lo.y);transform=Matrix.Diagonal((scale,scale,scale,1))@Matrix.Rotation(math.pi,4,'Z')@Matrix.Translation(-(lo+hi)*.5)
for ob in obs:ob.matrix_world=transform@ob.matrix_world
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True;s.cycles.device='GPU'
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='METAL'
s.render.resolution_x=2048;s.render.resolution_y=2048;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=True
s.world=bpy.data.worlds.new('NeutralWorld');s.world.use_nodes=True;bg=s.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.65,.65,.65,1);bg.inputs['Strength'].default_value=.45
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=0
for name,pos,power,size in [('Key',(1,1.5,2),120,2.5),('Fill',(-1,-.5,1),85,2.5),('Rim',(0,-1,1.5),65,2)]:
 light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size;ob=bpy.data.objects.new(name,light);bpy.context.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=1.04;cam.data.clip_start=.001;s.camera=cam
views=[('01-hero',(1,1,.5)),('02-right',(1,0,.001)),('03-left',(-1,0,.001)),('04-front-muzzle',(0,1,.001)),('05-back-stock',(0,-1,.001)),('06-top',(0,.001,1)),('07-hero-reverse',(-1,-1,.5))]
records=[]
for name,direction in views:
 cam.location=Vector(direction).normalized()*3;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(D/(name+'-rgba.png'));bpy.ops.render.render(write_still=True);records.append({'id':name,'camera_blender':list(cam.location),'ortho_scale':1.04,'rgba':name+'-rgba.png','white_background':name+'.png'})
(D/'manifest.json').write_text(json.dumps({'source':str(src.relative_to(R)),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs),'renderer':'Blender Cycles Metal offline reference, NOT in-game','size':[2048,2048],'length_m':.905,'material':'Tripo high original PBR, no local repaint','coordinates':'Blender +Y muzzle, Z up; right camera +X, left -X; front muzzle +Y, back stock -Y','views':records,'no_paid_calls':True},indent=2));print('HUNYUAN_REFERENCES_COMPLETE')
