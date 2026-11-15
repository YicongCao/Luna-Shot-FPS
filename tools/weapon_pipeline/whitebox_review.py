"""B1 control proxy after Tripo shape review; original B0 remains the chronological whitebox."""
import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Euler,Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art_source/weapons/lc01/pipeline-v1/00-whitebox';OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
conv=Matrix.Rotation(math.pi/2,4,'X')
parts=json.loads((ROOT/'docs/design/rifle-blockout-parts.json').read_text())
mat=bpy.data.materials.new('Whitebox');mat.diffuse_color=(.6,.6,.6,1)
for p in parts:
 name=p['name'];dims=p['size'];pos=p['position'][:]
 if name.startswith(('P08','P09')):pos[1]-=.038
 if name.startswith('P12'):pos[2]=-[.326,.402,.478][int(name[-1])]
 if name=='P07_Cell':pos=[0,-.068,-.26];dims=[.1,.095,.24]
 if name.startswith(('P11','P12')):
  bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=dims[0]/2,depth=dims[1]);o=bpy.context.object
  for v in o.data.vertices:v.co=Matrix.Rotation(math.pi/2,3,'X')@v.co
 else:
  bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object
  for v in o.data.vertices:
   for i in range(3):v.co[i]*=dims[i]
 o.name=name;o.matrix_world=conv@Matrix.Translation(pos)@Euler(p['rotation'],'XYZ').to_matrix().to_4x4();o.data.materials.append(mat)
for name,p in {'SightRear':(0,.178,-.025),'SightFront':(0,.178,-.19),'Muzzle':(0,.063,-.665)}.items():
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.matrix_world=conv@Matrix.Translation(p)
scene=bpy.context.scene;scene['provenance']='B1 control proxy updated AFTER high shape review. H1 is image-generated; it is not a subdivision of B0/B1.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lc01-whitebox-b1.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'lc01-whitebox-b1.glb'),export_format='GLB',export_yup=True)
scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world.color=(.2,.2,.2);scene.display.shading.color_type='MATERIAL';scene.display.shading.show_cavity=True;scene.display.shading.background_type='WORLD'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.15
for name,pos in [('whitebox-hero',(1.5,1.4,.65)),('whitebox-side',(1.6,.2125,.15))]:
 cam.location=pos;cam.rotation_euler=(Vector((0,.2125,.02))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
