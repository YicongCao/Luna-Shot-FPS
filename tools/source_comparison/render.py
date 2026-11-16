"""Read-only source mesh comparison. Blender Workbench geometry views, NOT in-game.
Run with Blender --background --python render.py -- --stage <stage>.
"""
import bpy,json,math,sys,argparse
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/source-mesh-comparison';D.mkdir(parents=True,exist_ok=True)
a=argparse.ArgumentParser();a.add_argument('--stage',required=True);args=a.parse_args(sys.argv[sys.argv.index('--')+1:]);stage=args.stage
sources=[];notes=[];context=[]
def open_blend(rel):
 sources.append(rel);bpy.ops.wm.open_mainfile(filepath=str(R/rel))
def import_glb(rel):
 sources.append(rel);bpy.ops.import_scene.gltf(filepath=str(R/rel));return [o for o in bpy.context.selected_objects if o.type=='MESH']
def clear():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def keep_only(names):
 for o in list(bpy.context.scene.objects):
  if o.name not in names:bpy.data.objects.remove(o,do_unlink=True)
def bounds(obs):
 bpy.context.view_layer.update();points=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box]
 return Vector([min(p[i] for p in points) for i in range(3)]),Vector([max(p[i] for p in points) for i in range(3)])
def append_blend(rel,suffix):
 sources.append(rel)
 with bpy.data.libraries.load(str(R/rel),link=False) as (src,dst):dst.objects=[n for n in src.objects if n.endswith(suffix)]
 for ob in dst.objects:
  if ob: bpy.context.collection.objects.link(ob)
 return [o for o in dst.objects if o and o.type=='MESH']
if stage=='gun-tripo':
 clear();obs=import_glb('art_source/weapons/lc01/pipeline-v1/01-tripo-geometry/model.glb')
 # Same proper 180-degree rotation and uniform scale used by original prepare_high.py.
 scale=.905/(.4902733564376831+.49005523324012756)
 transform=Matrix.Translation((0,.2125,.034))@Matrix.Diagonal((scale,scale,scale,1))@Matrix.Rotation(math.pi,4,'Z')
 for ob in obs:ob.matrix_world=transform@ob.matrix_world
 notes.append('Original mesh, including original tiny residual part; only rigid rotation + uniform scale/translation for comparison.')
elif stage.startswith('gun-ml06'):
 level=stage.rsplit('-',1)[1];folder='02-high' if level=='high' else '04-low'
 open_blend(f'art_source/weapons/lc01/industrial-wear-v1/{folder}/lc01-{level}.blend')
 keep_only({o.name for o in bpy.context.scene.objects if o.type=='MESH'})
 notes.append('ML06 source body: preserved/repaired Tripo-derived geometry, NOT whole-body procedural rebuild. Later field kit excluded.')
elif stage.startswith('gun-ml07'):
 level=stage.rsplit('-',1)[1];base='art_source/weapons/lc01/ls01-refine-v1';m=json.loads((R/base/'manifest.json').read_text())
 open_blend(base+'/02-geometry/paired.blend')
 # Body-only comparison excludes the later kit on every weapon version.
 keep_only({p[level] for p in m['pairs'] if p['group']=='body'})
 old=import_glb(base+'/00-baseline/lc01/lc01.glb')
 for ob in old:
  if any(ob.name.startswith(p) for p in m['replaced_prefixes']):bpy.data.objects.remove(ob,do_unlink=True)
  else:context.append(ob.name)
 notes.append('ML07 rebuilt body '+level+' plus identical retained LOW meshes for assembly context in both columns. Excludes industrial kit and export-added front screw copies; source-pair comparison, not final runtime assembly.')
elif stage=='b2-tripo':
 clear();obs=import_glb('art_source/environment/refine-v2/B2/01-tripo/model.glb')
 lo,hi=bounds(obs);s=6/(hi.z-lo.z);center=(lo+hi)*.5
 # Align the raw central-pipe face (+X) with the local module's front (-Y).
 # Do not mirror the raw assembly to force its side attachments to agree.
 transform=Matrix.Translation((0,0,3))@Matrix.Rotation(-math.pi/2,4,'Z')@Matrix.Diagonal((s,s,s,1))@Matrix.Translation(-center)
 for ob in obs:ob.matrix_world=transform@ob.matrix_world
 notes.append('Original Tripo geometry; uniform normalization to 6m height, -90 degree Z rotation aligning central-pipe face to -Y, centered module frame. No mirroring, per-axis stretching or part deletion. Raw side mounts may differ from local placement.')
elif stage.startswith('b2-'):
 level=stage.rsplit('-',1)[1];base='art_source/environment/refine-v2/B2';m=json.loads((R/base/'manifest.json').read_text());open_blend(base+'/02-geometry/paired.blend');keep_only({p[level] for p in m['pairs']})
 notes.append('ML15 static source body only. Runtime ML14 fans and programmatic lamps excluded; any analogous forms in raw Tripo remain original.')
else:raise ValueError(stage)
obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in obs:o.hide_set(False);o.hide_render=False;o.hide_viewport=False
lo,hi=bounds(obs);triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
if not scene.world:scene.world=bpy.data.worlds.new('ComparisonWorld')
scene.world.color=(.075,.085,.10)
sh=scene.display.shading;sh.light='STUDIO';sh.studio_light='paint.sl';sh.color_type='SINGLE';sh.single_color=(.58,.60,.63);sh.show_shadows=True;sh.show_cavity=False;sh.background_type='WORLD';sh.show_specular_highlight=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.clip_start=.001;cam.data.clip_end=1000
if stage.startswith('gun'):
 scene.render.resolution_x=1400;scene.render.resolution_y=900
 views=[('hero',Vector((0,.2125,.02)),Vector((1.6,-1,.60)),1.12),('side',Vector((0,.2125,.02)),Vector((2,0,.02)),1.12),('detail',Vector((0,.17,-.035)),Vector((2,0,.15)),.46)]
else:
 scene.render.resolution_x=1100;scene.render.resolution_y=1100
 views=[('hero',Vector((0,0,3)),Vector((1,-1,.55)),8.0),('side',Vector((0,0,3)),Vector((1,0,.1)),8.0),('detail',Vector((0,-1,.65)),Vector((1,-2,.55)),4.2)]
records=[]
for name,center,direction,scale in views:
 cam.location=center+direction.normalized()*scale*3;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 scene.render.filepath=str(D/f'{stage}-{name}.png');bpy.ops.render.render(write_still=True)
 records.append({'view':name,'center':list(center),'camera':list(cam.location),'ortho_scale':scale,'file':f'{stage}-{name}.png'})
(D/f'{stage}.json').write_text(json.dumps({'stage':stage,'renderer':'Blender Workbench offline; not game','geometry_only':True,'baked_normals_enabled':False,'sources':sources,'notes':notes,'retained_low_context':context,'objects':len(obs),'triangles_including_context':triangles,'bounds':[list(lo),list(hi)],'views':records},indent=2))
print('COMPARISON_RENDERED',stage,triangles,flush=True)
