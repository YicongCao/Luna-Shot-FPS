import bpy,bmesh,numpy as np,json
from pathlib import Path
import os
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'art_source/weapons/lc01'/os.environ.get('LC01_PIPELINE','pipeline-v1');OUT=BASE/'04-low'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'lc01-low.blend'))
report={'meshes':[]}
for ob in bpy.context.scene.objects:
 if ob.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(ob.data)
 report['meshes'].append({'name':ob.name,'triangles':len(bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_nonboundary_edges':sum(not e.is_manifold and not e.is_boundary for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-12 for f in bm.faces)})
 bm.free()
mask=np.load(BASE/'07-final/material-masks.npz')['coverage'].astype(bool)
for name in ['NormalGL','AO']:
 im=bpy.data.images.load(str(BASE/'05-bake'/f'{name}.png'),check_existing=False);im.colorspace_settings.name='Non-Color';v=np.empty(im.size[0]*im.size[1]*4,np.float32);im.pixels.foreach_get(v);a=v.reshape(im.size[1],im.size[0],4)[:,:,:3][mask]
 stats={'covered_pixels':len(a),'black_pixels':int(np.sum(a.max(1)<.01)),'min':float(a.min()),'max':float(a.max())}
 if name=='NormalGL':
  length=np.linalg.norm(a*2-1,axis=1);stats['length_p01']=float(np.quantile(length,.01));stats['length_p99']=float(np.quantile(length,.99));stats['flat_normal_fraction']=float(np.mean(np.linalg.norm(a-np.array([.5,.5,1]),axis=1)<.008))
 report[name]=stats
(OUT/'source-audit.json').write_text(json.dumps(report,indent=2))
# UV checker preview on canonical low. This is a diagnostic render, not a final asset.
checker=bpy.data.images.new('UV checker',width=2048,height=2048);checker.generated_type='COLOR_GRID'
mat=bpy.data.materials.new('UV_CHECKER_ONLY');mat.use_nodes=True;n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=checker;bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');mat.node_tree.links.new(n.outputs['Color'],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=.8
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':ob.data.materials.clear();ob.data.materials.append(mat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.35,.35,.35,1)
bpy.ops.object.light_add(type='AREA',location=(1.5,1.0,2));light=bpy.context.object;light.data.energy=150;light.data.size=2;light.rotation_euler=(Vector((0,.2,.03))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1.5,1.4,.65));cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.15;cam.rotation_euler=(Vector((0,.2125,.02))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'uv-checker.png');bpy.ops.render.render(write_still=True)
print('AUDIT_COMPLETE',json.dumps(report))
