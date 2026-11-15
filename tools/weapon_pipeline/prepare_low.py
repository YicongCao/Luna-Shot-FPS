import bpy,bmesh,json,math,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'art_source/weapons/lc01/pipeline-v1';OUT=BASE/'04-low'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'lc01-low-import.blend'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
# Remote retopology normalizes and recentres; restore the exact source coordinate frame.
pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
# Derived from the original dense source, not the returned preview.
source=json.loads((BASE/'raw-inspection.json').read_text())
rawlo=np.min(np.array([o['min'] for o in source if o['name']!='tripo_part_17']),axis=0);rawhi=np.max(np.array([o['max'] for o in source if o['name']!='tripo_part_17']),axis=0)
s=.905/(rawhi[1]-rawlo[1]);hc=Vector((-(rawhi[0]+rawlo[0])/2*s,-(rawhi[1]+rawlo[1])/2*s+.2125,(rawhi[2]+rawlo[2])/2*s+.034))
scale=.905/(hi.y-lo.y);offset=hc-(hi+lo)*.5*scale
mat=bpy.data.materials.new('LC01_LowAtlas');mat.use_nodes=True;mat.diffuse_color=(.52,.55,.57,1)
bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.52,.55,.57,1);bs.inputs['Roughness'].default_value=.6
stats=[]
for obj in meshes:
 obj.name=obj.name.replace('_high','_low');mw=obj.matrix_world.copy()
 for vert in obj.data.vertices:vert.co=(mw@vert.co)*scale+offset
 obj.matrix_world=Matrix.Identity(4)
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
 for f in obj.data.polygons:f.use_smooth=True
 obj.data.materials.clear();obj.data.materials.append(mat)
 obj['source_high']=obj.name.replace('_low','_high')
 bpy.context.view_layer.objects.active=obj
 tri=obj.modifiers.new('ExportTriangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
 wn=obj.modifiers.new('WeightedSurfaceNormals','WEIGHTED_NORMAL');wn.keep_sharp=True;wn.weight=50;bpy.ops.object.modifier_apply(modifier=wn.name)
 stats.append({'name':obj.name,'vertices':len(obj.data.vertices),'triangles':len(obj.data.polygons)})
# Retain Tripo's seam selection and chart layout; pack ALL part islands into one unique atlas.
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.select_all(action='SELECT');bpy.ops.uv.average_islands_scale();bpy.ops.uv.pack_islands(rotate=True,margin_method='FRACTION',margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
# Store local reassembly and finalized UVs before any texture service.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lc01-low.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'lc01-low.glb'),export_format='GLB',export_yup=True,export_extras=True)
(OUT/'low-report.json').write_text(json.dumps({'triangles':sum(o['triangles'] for o in stats),'parts':stats,'remote_normalization_reversed':{'scale':scale,'offset':list(offset)},'uv_repack':'Tripo charts, global equalized texel density and pack, 0.008 margin'},indent=2))
# Preview using exported geometry under neutral material, not remote preview's black default.
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world.color=(.2,.2,.2);scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH';scene.display.shading.background_type='WORLD'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.15
center=Vector((0,.2125,.02))
for name,pos in [('low-side',(1.6,.2125,.15)),('low-hero',(1.5,1.4,.65))]:
 cam.location=pos;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
print('PREPARE_LOW_COMPLETE')
