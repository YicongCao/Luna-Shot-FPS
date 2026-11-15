"""Audit saved low mesh and UV atlas without treating this as an art score."""
import bpy,json,sys,numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];asset=sys.argv[-1];base=ROOT/'art_source/environment/pipeline-v1'/asset
bpy.ops.wm.open_mainfile(filepath=str(base/'04-low'/f'{asset}-low.blend'))
report={'asset':asset,'parts':[],'triangles':0,'uv_out_of_bounds':0,'degenerate_uv_triangles':0}
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 assert o.data.uv_layers.active,o.name
 uv=o.data.uv_layers.active.data
 bounds=[list(o.matrix_world@v.co) for v in o.data.vertices]
 count=0;deg=0
 for p in o.data.polygons:
  coords=np.array([uv[i].uv[:] for i in p.loop_indices]);count+=int(coords.min()<-.00001 or coords.max()>1.00001)
  deg+=int(abs(np.linalg.det(np.stack([coords[1]-coords[0],coords[2]-coords[0]])))<1e-12)
 report['parts'].append({'name':o.name,'triangles':len(o.data.polygons),'uv_oob':count,'degenerate_uv':deg,'bounds':[np.min(bounds,axis=0).tolist(),np.max(bounds,axis=0).tolist()]})
 report['triangles']+=len(o.data.polygons);report['uv_out_of_bounds']+=count;report['degenerate_uv_triangles']+=deg
assert report['uv_out_of_bounds']==0
(base/'04-low/audit.json').write_text(json.dumps(report,indent=2))
print('LOW_AUDIT',json.dumps(report))
from mathutils import Vector
im=bpy.data.images.new('UV_Checker',1024,1024);im.generated_type='COLOR_GRID'
mat=bpy.data.materials.new('UV_Checker');mat.use_nodes=True;n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=im;mat.node_tree.nodes.active=n;mat.node_tree.links.new(n.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in obs:o.data.materials.clear();o.data.materials.append(mat)
points=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)]);center=(lo+hi)*.5;size=max(hi-lo)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.display.shading.color_type='TEXTURE';scene.display.shading.light='STUDIO'
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=size*1.5;cam.location=center+Vector((1,-1,.7))*size*2;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam;scene.render.filepath=str(base/'04-low/uv-checker.png');bpy.ops.render.render(write_still=True)
