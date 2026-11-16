"""Actual 4K Cycles selected-to-active baking, exploded per-part cages.
Source detail lives on high geometry/materials; low UV/normals are frozen.
"""
import bpy,sys,argparse,json,time
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--out',default=str(R/'art_source/environment/refine-v2/B1'));a.add_argument('--group',choices=['body','kit'],required=True);a.add_argument('--resolution',type=int,default=4096);a.add_argument('--maps',default='NormalGL,AO,BaseColor,Roughness,Metallic,Curvature,EdgeMask,Position,WorldNormal,MaterialID,WearMask,OilMask')
args=a.parse_args(sys.argv[sys.argv.index('--')+1:]);O=Path(args.out);D=O/'03-bake'/args.group;D.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from bake_contract import check
contract=check(D,O/'02-geometry/paired.blend',args.resolution)
bpy.ops.wm.open_mainfile(filepath=str(O/'02-geometry/paired.blend'))
manifest=json.loads((O/'manifest.json').read_text());ps=[p for p in manifest['pairs'] if p['group']==args.group]
keep={p[k] for p in ps for k in ['low','high','cage']}
for ob in list(bpy.context.scene.objects):
 if ob.name not in keep:bpy.data.objects.remove(ob,do_unlink=True)
highs=[];lows=[];cages=[]
for i,p in enumerate(ps):
 offset=Vector((i*24.,0,0));hi=bpy.data.objects[p['high']];lo=bpy.data.objects[p['low']];ca=bpy.data.objects[p['cage']]
 for ob in [hi,lo,ca]:ob.hide_set(False);ob.hide_render=False;ob.location+=offset
 highs.append(hi);lows.append(lo);cages.append(ca)
 anchor=bpy.data.objects.new(p['name']+'_texture_origin',None);bpy.context.collection.objects.link(anchor);anchor.location=hi.location.copy() # Do not read a stale matrix_world before depsgraph update.
 # Per-piece auxiliaries remove explosion translation; source object coordinates remain stable.
 for slot in hi.material_slots:
  m=(slot.material or next(x for x in hi.data.materials if x is not None)).copy();slot.material=m;n=m.node_tree.nodes;l=m.node_tree.links
  for tc in n:
   if tc.type=='TEX_COORD':tc.object=anchor
  geom=next(q for q in n if q.type=='NEW_GEOMETRY')
  # Keep designed edge-distance mask distinct from actual high-mesh pointiness.
  n['CHANNEL_Curvature'].name='CHANNEL_EdgeMask'
  q=n.new('NodeReroute');q.name='CHANNEL_Curvature';l.new(geom.outputs['Pointiness'],q.inputs[0])
  sub=n.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=offset;l.new(geom.outputs['Position'],sub.inputs[0]);scale=n.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs[3].default_value=1.;l.new(sub.outputs[0],scale.inputs[0])
  # Position encodes rebuilt-part source coordinates with +.5 on every axis; EXR retains full range.
  add=n.new('ShaderNodeVectorMath');add.operation='ADD';add.inputs[1].default_value=(.5,.5,.5);l.new(scale.outputs[0],add.inputs[0]);q=n.new('NodeReroute');q.name='CHANNEL_Position';l.new(add.outputs[0],q.inputs[0])
  mul=n.new('ShaderNodeVectorMath');mul.operation='SCALE';mul.inputs[3].default_value=.5;l.new(geom.outputs['Normal'],mul.inputs[0]);ad=n.new('ShaderNodeVectorMath');ad.operation='ADD';ad.inputs[1].default_value=(.5,.5,.5);l.new(mul.outputs[0],ad.inputs[0]);q=n.new('NodeReroute');q.name='CHANNEL_WorldNormal';l.new(ad.outputs[0],q.inputs[0])
  q=n.new('NodeReroute');q.name='CHANNEL_MaterialID';l.new(n['MATERIAL_ID'].outputs[0],q.inputs[0])

def join(objs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();bpy.context.object.name=name;return bpy.context.object
lo=join(lows,'Atlas_low');ca=join(cages,'Atlas_cage');ca.hide_render=True
highs=[join(highs,'Atlas_high')] # One source avoids a full-atlas render per source object.
assert len(lo.data.vertices)==len(ca.data.vertices)
assert [tuple(p.vertices) for p in lo.data.polygons]==[tuple(p.vertices) for p in ca.data.polygons]
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.device='GPU';s.cycles.samples=16;s.render.threads_mode='FIXED';s.render.threads=8
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
for device in prefs.devices:device.use=device.type=='METAL'
print('BAKE_DEVICE',[(d.name,d.type,d.use) for d in prefs.devices],flush=True)
b=s.render.bake;b.use_selected_to_active=True;b.use_clear=True;b.margin=32 if args.resolution==4096 else 16;b.use_cage=True;b.cage_object=ca;b.max_ray_distance=.06;b.normal_space='TANGENT';b.normal_r='POS_X';b.normal_g='POS_Y';b.normal_b='POS_Z'
mat=bpy.data.materials.new('BakeTarget');mat.use_nodes=True;lo.data.materials.clear();lo.data.materials.append(mat)
for p in lo.data.polygons:p.material_index=0
node=mat.node_tree.nodes.new('ShaderNodeTexImage');mat.node_tree.nodes.active=node
bpy.ops.object.select_all(action='DESELECT')
for hi in highs:hi.select_set(True)
lo.select_set(True);bpy.context.view_layer.objects.active=lo
prior=json.loads((D/'report.json').read_text()) if (D/'report.json').exists() else {}
report={'contract':contract,'group':args.group,'resolution':args.resolution,'device':'Apple M5 Metal GPU','actual_cycles_bake':True,'selected_to_active':True,'explicit_cage':True,'exploded_pairs':len(ps),'source_batch':'joined high; per-part object-coordinate anchors preserved','margin_px':b.margin,'maps':prior.get('maps',[]),'curvature_encoding':'Cycles high-mesh Pointiness, .5 flat; not a signed metric curvature','edge_mask':'controlled edge-distance wear proxy, distinct from Curvature','ao_scope':'per-part local AO; exploded to avoid unrelated parts','position_encoding':'Blender source xyz + (.5,.5,.5)'}
originals={m.name:next(q for q in m.node_tree.nodes if q.type=='BSDF_PRINCIPLED') for hi in highs for m in hi.data.materials}
for name in args.maps.split(','):
 dest=D/(name+'.png')
 if dest.exists():print('BAKE_CACHED',name,flush=True);continue
 kind={'NormalGL':'NORMAL','AO':'AO'}.get(name,'EMIT')
 for hi in highs:
  for m in hi.data.materials:
   n=m.node_tree.nodes;l=m.node_tree.links;out=next(q for q in n if q.type=='OUTPUT_MATERIAL')
   for link in list(out.inputs['Surface'].links):l.remove(link)
   if kind in ['NORMAL','AO']:l.new(originals[m.name].outputs[0],out.inputs['Surface'])
   else:
    em=n.get('BakeChannel') or n.new('ShaderNodeEmission');em.name='BakeChannel';l.new(n['CHANNEL_'+name].outputs[0],em.inputs['Color']);l.new(em.outputs[0],out.inputs['Surface'])
 im=bpy.data.images.new(name,args.resolution,args.resolution,alpha=False,float_buffer=name=='Position');im.colorspace_settings.name='sRGB' if name=='BaseColor' else 'Non-Color';im.generated_color=(.5,.5,1,1) if name=='NormalGL' else (0,0,0,1);node.image=im
 s.cycles.samples=8 if kind=='AO' else (4 if kind=='NORMAL' else 1)
 t=time.time();bpy.ops.object.bake(type=kind);im.filepath_raw=str(dest);im.file_format='PNG';im.save()
 if name=='Position':
  im.filepath_raw=str(D/'Position.exr');im.file_format='OPEN_EXR';im.save()
 report['maps'].append({'name':name,'seconds':time.time()-t,'bake_type':kind});(D/'report.json').write_text(json.dumps(report,indent=2));print('BAKED',args.group,name,time.time()-t,flush=True);bpy.data.images.remove(im)
report['completed']=all((D/(name+'.png')).exists() for name in args.maps.split(','));(D/'report.json').write_text(json.dumps(report,indent=2))
# Keep cage scene reviewable and source shader restored.
for hi in highs:
 for m in hi.data.materials:
  n=m.node_tree.nodes;l=m.node_tree.links;out=next(q for q in n if q.type=='OUTPUT_MATERIAL');l.new(originals[m.name].outputs[0],out.inputs['Surface'])
bpy.ops.wm.save_as_mainfile(filepath=str(D/'bake-pairs.blend'));print('BAKE_COMPLETE',flush=True)
