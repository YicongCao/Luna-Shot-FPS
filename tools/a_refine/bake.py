"""Project authored detail/materials onto fixed low UV; keep paired scene and real normal/AO."""
import bpy,json,numpy as np,shutil,time
from pathlib import Path
R=Path(__file__).resolve().parents[2];B=R/'art_source/environment/A-refine-v2';O=B/'03-bake';O.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(B/'02-low/A-low.blend'));lo=bpy.data.objects['A_low']
with bpy.data.libraries.load(str(B/'01-high/A-high.blend')) as (src,dst):dst.objects=['A_high']
hi=dst.objects[0];bpy.context.collection.objects.link(hi)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.device='CPU'
b=s.render.bake;b.use_selected_to_active=True;b.use_clear=True;b.margin=8;b.cage_extrusion=.025;b.max_ray_distance=.065;b.normal_space='TANGENT';b.use_pass_direct=False;b.use_pass_indirect=False;b.use_pass_color=True
nodes=[]
for slot in lo.material_slots:
 m=slot.material.copy();slot.material=m;n=m.node_tree.nodes.new('ShaderNodeTexImage');m.node_tree.nodes.active=n;nodes.append(n)
bpy.ops.object.select_all(action='DESELECT');lo.select_set(True);hi.select_set(True);bpy.context.view_layer.objects.active=lo
images={};records=[]
for name,kind,neutral in [('NormalGL','NORMAL',(.5,.5,1,1)),('AO','AO',(1,1,1,1)),('Roughness','ROUGHNESS',(.5,.5,.5,1))]:
 im=bpy.data.images.new(name,2048,2048,alpha=False);im.generated_color=neutral;im.colorspace_settings.name='sRGB' if name=='BaseColor' else 'Non-Color'
 for n in nodes:n.image=im
 start=time.time();bpy.ops.object.bake(type=kind);im.filepath_raw=str(O/(name+'.png'));im.file_format='PNG';im.save();images[name]=im
 records.append({'map':name,'kind':kind,'seconds':time.time()-start});print('A_BAKED',name,flush=True)
# Bake scalar metallic and the tiny diagnostic indicator from the high source materials.
for name in ['BaseColor','Metallic','Emission']:
 for mat in hi.data.materials:
  bs=mat.node_tree.nodes.get('Principled BSDF');out=mat.node_tree.nodes.get('Material Output')
  for link in list(out.inputs['Surface'].links):mat.node_tree.links.remove(link)
  em=mat.node_tree.nodes.new('ShaderNodeEmission')
  if name=='BaseColor':color=tuple(bs.inputs['Base Color'].default_value)
  elif name=='Metallic':
   v=bs.inputs['Metallic'].default_value;color=(v,v,v,1)
  else:color=(.025,.65,.8,1) if mat.name.startswith('cyan') else (0,0,0,1)
  em.inputs['Color'].default_value=color;mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
 im=bpy.data.images.new(name,2048,2048,alpha=False);im.colorspace_settings.name='sRGB' if name in ['BaseColor','Emission'] else 'Non-Color'
 for n in nodes:n.image=im
 start=time.time();bpy.ops.object.bake(type='EMIT');im.filepath_raw=str(O/(name+'.png'));im.file_format='PNG';im.save();images[name]=im
 records.append({'map':name,'kind':'EMIT material channel','seconds':time.time()-start});print('A_BAKED',name,flush=True)
def pixels(im):
 a=np.empty(2048*2048*4,np.float32);im.pixels.foreach_get(a);return a.reshape(2048,2048,4)
arr=np.ones((2048,2048,4),np.float32)
for i,name in enumerate(['AO','Roughness','Metallic']):arr[:,:,i]=pixels(images[name])[:,:,0]
im=bpy.data.images.new('ORM',2048,2048,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(arr.ravel());im.filepath_raw=str(O/'ORM.png');im.file_format='PNG';im.save()
# Preserve original source shader materials in high Blend; this pair scene contains bake-channel nodes.
bpy.ops.wm.save_as_mainfile(filepath=str(O/'A-bake-pairs.blend'))
(O/'report.json').write_text(json.dumps({'completed':True,'selected_to_active':True,'high_source':'01-high/A-high.blend','low_source':'02-low/A-low.blend','resolution':2048,'margin_px':8,'extrusion_m':.025,'max_distance_m':.065,'samples':16,'maps':records},indent=2))
# Export the untouched fixed low geometry/UV with a single baked runtime material.
bpy.ops.wm.open_mainfile(filepath=str(B/'02-low/A-low.blend'));lo=bpy.data.objects['A_low']
mat=bpy.data.materials.new('A_v2_Atlas');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');links=mat.node_tree.links;nodes=mat.node_tree.nodes
for name,socket in [('BaseColor','Base Color'),('Emission','Emission Color')]:
 tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(O/(name+'.png')));tex.image.colorspace_settings.name='sRGB';links.new(tex.outputs['Color'],bs.inputs[socket])
bs.inputs['Emission Strength'].default_value=2.0
tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(O/'ORM.png'));tex.image.colorspace_settings.name='Non-Color';sep=nodes.new('ShaderNodeSeparateColor');links.new(tex.outputs['Color'],sep.inputs[0]);links.new(sep.outputs['Green'],bs.inputs['Roughness']);links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(O/'NormalGL.png'));tex.image.colorspace_settings.name='Non-Color';nm=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],nm.inputs[0]);links.new(nm.outputs[0],bs.inputs['Normal'])
lo.data.materials.clear();lo.data.materials.append(mat)
for p in lo.data.polygons:p.material_index=0
F=B/'04-final';F.mkdir(exist_ok=True)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(F/'A-final.blend'))
bpy.ops.export_scene.gltf(filepath=str(F/'A.glb'),export_format='GLB',use_selection=True,export_materials='NONE',export_tangents=True)
for name in ['BaseColor','NormalGL','ORM','Emission']:shutil.copy2(O/(name+'.png'),F/(name+'.png'))
(F/'provenance.json').write_text(json.dumps({'asset':'A','revision':'concept-refine-v2','triangles':len(lo.data.polygons),'source':str(F.relative_to(R)),'normal':'genuine selected-to-active bake from separately authored high geometry','texture_resolution':2048,'material_slots':1,'tripo_credits_this_revision':0},indent=2))
print('A_FINAL_COMPLETE',len(lo.data.polygons),flush=True)
