import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]; BASE=ROOT/'art_source/weapons/lc01/pipeline-v1'; OUT=BASE/'02-high';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'raw-import.blend'))
# Original Tripo model: Blender -Y points to muzzle. Normalize uniformly to 0.905 m length.
scale=.905/(.4902733564376831+.49005523324012756)
labels={0:'CoreGrip',1:'FrontShroud',2:'CoilAssembly',3:'ReceiverShell',4:'EnergyCell',5:'Optic',6:'Muzzle',7:'TopRail',8:'StockShell',9:'StockBrace',10:'ButtPad',11:'CellSide',12:'Foregrip',13:'CheekRest',14:'FrontBracket',15:'RailInset',16:'FrontLatch'}
report=[]
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH': bpy.data.objects.remove(obj,do_unlink=True);continue
 idx=int(obj.name.split('_')[-1])
 if idx not in labels: bpy.data.objects.remove(obj,do_unlink=True);continue
 # Bake world transform into vertices then a proper coordinate rotation (not a mirror).
 mw=obj.matrix_world.copy()
 for v in obj.data.vertices:
  p=mw@v.co;v.co=Vector((-p.x*scale,-p.y*scale+.2125,p.z*scale+.034))
 obj.matrix_world=Matrix.Identity(4)
 obj.name=f'T{idx:02d}_{labels[idx]}_high'
 bm=bmesh.new();bm.from_mesh(obj.data)
 before=len(bm.verts)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000002)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 # Preserve generated hard-surface shape; do not subdivide low detail to fake high-poly.
 bm.to_mesh(obj.data);bm.free()
 for poly in obj.data.polygons: poly.use_smooth=True
 mat=bpy.data.materials.new('Clay_'+labels[idx]);mat.diffuse_color=(.52,.55,.57,1);mat.use_nodes=True
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.52,.55,.57,1);bs.inputs['Roughness'].default_value=.65
 obj.data.materials.clear();obj.data.materials.append(mat)
 obj['tripo_part']=idx;obj['stage']='H1 cleaned dense generated geometry'
 report.append({'name':obj.name,'vertices_before':before,'vertices_after':len(obj.data.vertices),'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons)})
# high export used as the next exact remote task input
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lc01-high.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'lc01-high.glb'),export_format='GLB',export_materials='NONE',export_yup=True,export_extras=True)
(OUT/'geometry-report.json').write_text(json.dumps({'scale':scale,'normalization':'Blender +Y forward, +Z up; Godot -Z forward +Y up','parts':report},indent=2))
# Workbench clay and segmented views for shape inspection. Does not modify saved source.
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world.color=(.2,.2,.2)
scene.display.shading.light='STUDIO';scene.display.shading.studiolight_rotate_z=.5
scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True
scene.display.shading.cavity_type='BOTH';scene.display.shading.background_type='WORLD'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.15
center=Vector((0,.2125,.02))
for name,pos in [('clay-side',(1.6,.2125,.15)),('clay-hero',(1.5,1.4,.65)),('clay-back',(-1.5,-.6,.5)),('clay-ads',(0,-1.2,.17))]:
 cam.location=pos;target=center if name!='clay-ads' else Vector((0,.1,.17));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
print('PREPARE_HIGH_COMPLETE')
