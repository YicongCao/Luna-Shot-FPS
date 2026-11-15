"""True Cycles high-to-low bake. One isolated high/low part pair per pass."""
import bpy,json,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];asset=sys.argv[-1];BASE=ROOT/'art_source/environment/pipeline-v1'/asset;OUT=BASE/'05-bake';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'04-low'/f'{asset}-low.blend'))
lows=[o for o in bpy.context.scene.objects if o.type=='MESH']
with bpy.data.libraries.load(str(BASE/'02-high'/f'{asset}-high.blend')) as (src,dst):dst.objects=[n for n in src.objects if n.endswith('_high')]
highs={o.name:o for o in dst.objects if o}
for o in highs.values():bpy.context.collection.objects.link(o)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.device='CPU'
bake=scene.render.bake;bake.use_selected_to_active=True;bake.use_clear=False;bake.margin=16;bake.use_cage=False;bake.cage_extrusion=.025;bake.max_ray_distance=.075;bake.normal_space='TANGENT'
images={}
for kind,color in [('NORMAL',(.5,.5,1,1)),('AO',(1,1,1,1))]:
 im=bpy.data.images.new(asset+'_'+kind,2048,2048,alpha=False);im.generated_color=color;im.colorspace_settings.name='Non-Color';images[kind]=im
for o in lows:
 m=bpy.data.materials.new(o.name+'_BakeTarget');m.use_nodes=True;o.data.materials.clear();o.data.materials.append(m);n=m.node_tree.nodes.new('ShaderNodeTexImage');n.name='BAKE_TARGET';m.node_tree.nodes.active=n
for o in highs.values():o.hide_render=True;o.hide_set(True)
report={'asset':asset,'selected_to_active':True,'resolution':2048,'samples':16,'device':'CPU','margin_px':16,'extrusion_m':.025,'max_ray_distance_m':.075,'pairs':[]}
for lo in lows:
 name=lo.name.replace('_low','_high');assert name in highs,(name,list(highs))
 high=highs[name]
 for o in bpy.context.selected_objects:o.select_set(False)
 for o in lows:o.hide_render=True
 lo.hide_render=False;high.hide_render=False;high.hide_set(False);high.select_set(True);lo.select_set(True);bpy.context.view_layer.objects.active=lo
 start=time.time();n=lo.data.materials[0].node_tree.nodes.get('BAKE_TARGET')
 for kind,im in images.items():
  n.image=im;bpy.ops.object.bake(type=kind,use_selected_to_active=True,use_clear=False)
 high.hide_render=True;high.hide_set(True);high.select_set(False)
 report['pairs'].append({'low':lo.name,'high':name,'seconds':time.time()-start,'low_triangles':len(lo.data.polygons),'high_triangles':sum(len(p.vertices)-2 for p in high.data.polygons)})
 (OUT/'progress.json').write_text(json.dumps(report,indent=2));print('PAIR_COMPLETE',lo.name,flush=True)
for kind,im in images.items():
 im.filepath_raw=str(OUT/('NormalGL.png' if kind=='NORMAL' else 'AO.png'));im.file_format='PNG';im.save()
for o in lows:o.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{asset}-bake-pairs.blend'))
report['completed']=True;(OUT/'bake-report.json').write_text(json.dumps(report,indent=2));print('BAKE_COMPLETE',asset)
