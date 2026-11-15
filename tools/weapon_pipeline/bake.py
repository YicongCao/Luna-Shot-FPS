"""Real selected-to-active Cycles normal/AO baking from dense high to final low."""
import bpy,json,time,numpy as np
from pathlib import Path
import os
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'art_source/weapons/lc01'/os.environ.get('LC01_PIPELINE','pipeline-v1');OUT=BASE/'05-bake';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'04-low/lc01-low.blend'))
lows=[o for o in bpy.context.scene.objects if o.type=='MESH']
with bpy.data.libraries.load(str(BASE/'02-high/lc01-high.blend'),link=False) as (data_from,data_to):data_to.objects=[n for n in data_from.objects if n.endswith('_high')]
for obj in data_to.objects:
 if obj:bpy.context.collection.objects.link(obj)
highs={o.name:o for o in data_to.objects if o}
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.bake.use_selected_to_active=True;scene.render.bake.use_clear=False;scene.render.bake.margin=16;scene.render.bake.use_cage=False
scene.render.bake.cage_extrusion=.006;scene.render.bake.max_ray_distance=.018
scene.render.bake.normal_space='TANGENT';scene.render.bake.normal_r='POS_X';scene.render.bake.normal_g='POS_Y';scene.render.bake.normal_b='POS_Z'
# CPU is portable and reproducible; all bake evidence records the actual device.
scene.cycles.device='CPU'
normal=bpy.data.images.new('LC01_NormalGL_BAKED',2048,2048,alpha=False,float_buffer=False);normal.generated_color=(.5,.5,1,1);normal.colorspace_settings.name='Non-Color'
ao=bpy.data.images.new('LC01_AO_BAKED',2048,2048,alpha=False,float_buffer=False);ao.generated_color=(1,1,1,1);ao.colorspace_settings.name='Non-Color'
# Unique bake materials keep source and target nodes completely separate.
for lo in lows:
 mat=bpy.data.materials.new(lo.name+'_BakeTarget');mat.use_nodes=True;lo.data.materials.clear();lo.data.materials.append(mat)
 node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.name='BAKE_TARGET';node.image=normal;mat.node_tree.nodes.active=node
 bpy.context.view_layer.objects.active=lo
report={'resolution':[2048,2048],'engine':'CYCLES','device':'CPU','selected_to_active':True,'normal_space':'TANGENT +X +Y +Z','margin_px':16,'cage_extrusion_m':.006,'max_ray_distance_m':.018,'pairs':[]}
for high in highs.values(): high.hide_render=True;high.hide_set(True)
for lo in lows:
 high=highs[lo.name.replace('_low','_high')]
 # Check geometric deviation independently of rendered appearance.
 verts=[high.matrix_world@v.co for v in high.data.vertices];polys=[list(p.vertices) for p in high.data.polygons]
 tree=BVHTree.FromPolygons(verts,polys,all_triangles=True)
 errors=[]
 for v in lo.data.vertices:
  hit=tree.find_nearest(lo.matrix_world@v.co)
  if hit[0] is not None:errors.append(hit[3])
 del tree,verts,polys
 start=time.time()
 for ob in bpy.context.selected_objects:ob.select_set(False)
 for ob in lows:ob.hide_render=True
 lo.hide_render=False;high.hide_render=False;high.hide_set(False)
 high.select_set(True);lo.select_set(True);bpy.context.view_layer.objects.active=lo
 node=lo.data.materials[0].node_tree.nodes.get('BAKE_TARGET')
 for kind,img in [('NORMAL',normal),('AO',ao)]:
  node.image=img;lo.data.materials[0].node_tree.nodes.active=node
  bpy.ops.object.bake(type=kind,use_selected_to_active=True,use_clear=False,margin=16,cage_extrusion=.006,max_ray_distance=.018)
 high.hide_render=True;high.hide_set(True);high.select_set(False)
 item={'low':lo.name,'high':high.name,'low_triangles':len(lo.data.polygons),'high_triangles':len(high.data.polygons),'surface_distance_p95_mm':float(np.percentile(errors,95)*1000),'surface_distance_max_mm':float(max(errors)*1000),'seconds':time.time()-start}
 report['pairs'].append(item);(OUT/'bake-progress.json').write_text(json.dumps(report,indent=2));print('BAKED_PAIR',json.dumps(item),flush=True)
for img,name in [(normal,'NormalGL.png'),(ao,'AO.png')]:
 img.filepath_raw=str(OUT/name);img.file_format='PNG';img.save()
for lo in lows:lo.hide_render=False
# Save the exact source/target pair scene; high hidden for a default low preview.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lc01-bake-pairs.blend'))
report['completed']=True;report['high_triangles']=sum(p['high_triangles'] for p in report['pairs']);report['low_triangles']=sum(p['low_triangles'] for p in report['pairs'])
(OUT/'bake-report.json').write_text(json.dumps(report,indent=2))
print('BAKE_COMPLETE',flush=True)
