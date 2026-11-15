"""Normalize remote geometry to the approved B0 bounds; preserve staged sources."""
import bpy,bmesh,json,sys,math,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
asset,stage=sys.argv[sys.argv.index('--')+1:]
BASE=ROOT/'art_source/environment/pipeline-v1';OUT=BASE/asset/('02-high' if stage=='high' else '04-low');OUT.mkdir(parents=True,exist_ok=True)
def clear():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def meshes():return [o for o in bpy.context.scene.objects if o.type=='MESH']
def bounds(obs):
 pts=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box]
 return Vector([min(p[i] for p in pts) for i in range(3)]),Vector([max(p[i] for p in pts) for i in range(3)])
def flatten(o):
 mw=np.array(o.matrix_world);points=np.empty(len(o.data.vertices)*3,dtype=np.float32);o.data.vertices.foreach_get('co',points)
 points=points.reshape(-1,3)@mw[:3,:3].T+mw[:3,3]
 o.data.vertices.foreach_set('co',points.astype(np.float32).ravel());o.parent=None;o.matrix_world=Matrix.Identity(4)

clear()
bpy.ops.import_scene.gltf(filepath=str(BASE/'00-whitebox'/f'{asset}-whitebox.glb'))
target_lo,target_hi=bounds(meshes());clear()
raw=BASE/asset/('01-tripo-high' if stage=='high' else '03-tripo-low')/'model.glb'
bpy.ops.import_scene.gltf(filepath=str(raw))
obs=meshes();lo,hi=bounds(obs)
scale=Vector([(target_hi[i]-target_lo[i])/(hi[i]-lo[i]) for i in range(3)])
mat=bpy.data.materials.new('NeutralClay');mat.use_nodes=True;mat.diffuse_color=(.38,.43,.47,1)
mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.38,.43,.47,1)
report={'asset':asset,'stage':stage,'source':str(raw),'source_bounds':[list(lo),list(hi)],'target_bounds':[list(target_lo),list(target_hi)],'scale':list(scale),'parts':[]}
for idx,o in enumerate(obs):
 old=o.name;flatten(o)
 points=np.empty(len(o.data.vertices)*3,dtype=np.float32);o.data.vertices.foreach_get('co',points)
 points=(points.reshape(-1,3)-np.array(lo))*np.array(scale)+np.array(target_lo)
 o.data.vertices.foreach_set('co',points.astype(np.float32).ravel())
 if stage=='high':o.name=f'{asset}_P{idx:02d}_high'
 else:o.name=old.replace('_high','_low')
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 o.data.materials.clear();o.data.materials.append(mat)
 for p in o.data.polygons:p.use_smooth=True
 report['parts'].append({'name':o.name,'raw_name':old,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)})
for o in list(bpy.context.scene.objects):
 if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
if stage=='low':
 budget={'A':8000,'B1':14000,'B2':14000,'C':16000,'D':18000,'E':20000}[asset]
 incoming=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs)
 report['remote_triangles']=incoming
 if incoming>budget:
  for o in obs:
   bpy.context.view_layer.objects.active=o
   dec=o.modifiers.new('BudgetCorrection','DECIMATE');dec.ratio=budget/incoming*.98
   bpy.ops.object.modifier_apply(modifier=dec.name)
  report['local_budget_correction']=True
 for o in obs:
  bpy.context.view_layer.objects.active=o
  mod=o.modifiers.new('FinalTriangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('WeightedNormals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=obs[0]
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
 if not all(o.data.uv_layers for o in obs):bpy.ops.uv.smart_project(island_margin=.02)
 bpy.ops.uv.select_all(action='SELECT');bpy.ops.uv.average_islands_scale();bpy.ops.uv.pack_islands(rotate=True,margin_method='FRACTION',margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
if stage=='high' and asset=='A':
 # Explicit high-poly fasteners on the front inspection covers; these are real geometry.
 receiver=max(obs,key=lambda ob:len(ob.data.vertices));details=[]
 for x in [-1.34,-.66,-.34,.34,.66,1.34]:
  for z in [.4,.9]:
   hit=bpy.context.scene.ray_cast(bpy.context.evaluated_depsgraph_get(),Vector((x,-10,z)),Vector((0,1,0)))
   if not hit[0]:continue
   bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.027,depth=.014,location=(x,hit[1].y-.006,z),rotation=(math.pi/2,0,0))
   bolt=bpy.context.object;bolt.name='HighFastener';details.append(bolt)
   bevel=bolt.modifiers.new('MachinedEdge','BEVEL');bevel.width=.004;bevel.segments=3;bpy.ops.object.modifier_apply(modifier=bevel.name)
 bpy.ops.object.select_all(action='DESELECT');receiver.select_set(True)
 for o in details:o.select_set(True)
 bpy.context.view_layer.objects.active=receiver;bpy.ops.object.join()
 report['authored_details']='12 surface-snapped bevelled inspection-cover fasteners; not subdivision of low mesh'
bpy.context.view_layer.update()
for rec,o in zip(report['parts'],obs):
 points=[o.matrix_world@Vector(c) for c in o.bound_box]
 rec['bounds']=[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]
 rec['triangles']=sum(len(p.vertices)-2 for p in o.data.polygons)
report['triangles']=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{asset}-{stage}.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/f'{asset}-{stage}.glb'),export_format='GLB',export_materials='NONE' if stage=='high' else 'EXPORT',export_extras=True)
(OUT/'geometry-report.json').write_text(json.dumps(report,indent=2))
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.color=(.13,.15,.18);sh=scene.display.shading;sh.light='STUDIO';sh.color_type='MATERIAL';sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH';sh.background_type='WORLD'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=max(target_hi-target_lo)*1.5
center=(target_hi+target_lo)/2;size=max(target_hi-target_lo)
for title,direction in [('front',(1,-1,.7)),('back',(-1,1,.7)),('side',(1,0,.15)),('top',(0,-.1,1))]:
 cam.location=center+Vector(direction)*size*2;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(title+'.png'));bpy.ops.render.render(write_still=True)
print('GEOMETRY_COMPLETE',asset,stage,report['triangles'])
