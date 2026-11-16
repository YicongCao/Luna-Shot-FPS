"""Read-only Blender inspection of user-provided Hunyuan exports; no mesh repair."""
import bpy,json,hashlib,sys,math
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/hunyuan-weapon-v1';D.mkdir(exist_ok=True,parents=True)
results=[]
for stage,name in [('hy-high','high.glb'),('hy-low','low.glb'),('hy-uv','uv.fbx'),('hy-pbr','pbr.glb')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 p=R/'art_source/weapons/lc01/hunyuan-v1'/name
 if p.suffix=='.fbx':bpy.ops.import_scene.fbx(filepath=str(p))
 else:bpy.ops.import_scene.gltf(filepath=str(p))
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.context.view_layer.update();parts=[]
 for o in obs:
  m=o.data;m.calc_loop_triangles();edge_counts={tuple(sorted(e.vertices)):0 for e in m.edges};deg=0
  for poly in m.polygons:
   if poly.area<1e-14:deg+=1
   vs=list(poly.vertices)
   for a,b in zip(vs,vs[1:]+vs[:1]):edge_counts[tuple(sorted((a,b)))]+=1
  uv=m.uv_layers.active
  uvs=[list(x.uv) for x in uv.data] if uv else []
  # Position-only sorted hash allows vertex-order-independent comparison with UV splits.
  vertices=sorted(set(tuple(round(float(x),6) for x in (o.matrix_world@v.co)) for v in m.vertices))
  parts.append({'name':o.name,'vertices':len(m.vertices),'triangles':len(m.loop_triangles),'polygons':len(m.polygons),'boundary_edges':sum(n==1 for n in edge_counts.values()),'nonmanifold_edges_gt2':sum(n>2 for n in edge_counts.values()),'degenerate_faces_area_lt_1e14':deg,'uv_layers':[u.name for u in m.uv_layers],'uv_loops':len(uvs),'uv_outside_01':sum(any(x<-.00001 or x>1.00001 for x in uv) for uv in uvs),'position_hash_round6':hashlib.sha256(json.dumps(vertices).encode()).hexdigest(),'uv_hash':hashlib.sha256(json.dumps(uvs).encode()).hexdigest()})
 points=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
 results.append({'stage':stage,'source':str(p.relative_to(R)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size,'bounds_blender':[list(lo),list(hi)],'parts':parts,'triangles':sum(x['triangles'] for x in parts),'materials':len(bpy.data.materials),'images':[{'name':im.name,'size':list(im.size)} for im in bpy.data.images]})
 # Normalize longest axis to .905m. Initial front orientation checked visually next.
 s=.905/max(hi-lo);tr=Matrix.Diagonal((s,s,s,1))@Matrix.Rotation(math.pi,4,'Z')@Matrix.Translation(-(hi+lo)*.5)
 for o in obs:o.matrix_world=tr@o.matrix_world
 sc=bpy.context.scene;sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1400;sc.render.resolution_y=900;sc.render.resolution_percentage=100
 sc.world=bpy.data.worlds.new('World');sc.world.color=(.075,.085,.10)
 sh=sc.display.shading;sh.light='STUDIO';sh.studio_light='paint.sl';sh.color_type='SINGLE';sh.single_color=(.58,.60,.63);sh.show_shadows=True;sh.show_cavity=False;sh.background_type='WORLD';sh.show_specular_highlight=True
 sc.view_settings.view_transform='Standard';sc.view_settings.look='None'
 bpy.ops.object.camera_add();cam=bpy.context.object;sc.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.12;cam.data.clip_start=.001
 for view,vec in [('hero',(1.6,-1,.6)),('side',(2,0,.02)),('reverse',(-1.6,1,.6))]:
  cam.location=Vector(vec).normalized()*3;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(D/f'{stage}-{view}.png');bpy.ops.render.render(write_still=True)
(D/'audit.json').write_text(json.dumps(results,indent=2));print('AUDIT_DONE',[(r['stage'],r['triangles']) for r in results])
