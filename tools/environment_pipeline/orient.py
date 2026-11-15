"""Orient closed shells by signed volume; open shells against approved B0 surface normals."""
import bpy,bmesh,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];asset=sys.argv[-1];BASE=ROOT/'art_source/environment/pipeline-v1'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(BASE/'00-whitebox'/f'{asset}-whitebox.glb'))
vertices=[];faces=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 off=len(vertices);vertices.extend([o.matrix_world@v.co for v in o.data.vertices]);faces.extend([[i+off for i in p.vertices] for p in o.data.polygons])
reference=BVHTree.FromPolygons(vertices,faces)
report={'asset':asset,'method':'Closed shells: signed volume; open shells: area-weighted nearest B0 normal votes, not blind volume flip','stages':{}}
for stage,folder in [('high','02-high'),('low','04-low')]:
 out=BASE/asset/folder;bpy.ops.wm.open_mainfile(filepath=str(out/f'{asset}-{stage}.blend'));rows=[]
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  bm=bmesh.new();bm.from_mesh(o.data);bm.faces.ensure_lookup_table();remaining=set(bm.faces);shells=[]
  while remaining:
   seed=remaining.pop();component=[seed];stack=[seed]
   while stack:
    f=stack.pop()
    for e in f.edges:
     for other in e.link_faces:
      if other in remaining:remaining.remove(other);component.append(other);stack.append(other)
   shells.append(component)
  reversed_count=0;details=[]
  for shell in shells:
   closed=all(e.is_manifold for f in shell for e in f.edges)
   volume=sum(f.verts[0].co.dot(f.verts[i].co.cross(f.verts[i+1].co))/6 for f in shell for i in range(1,len(f.verts)-1))
   vote=0.;weight=0.
   if not closed:
    for f in shell[::max(1,len(shell)//600)]:
     point=f.calc_center_median();hit=reference.find_nearest(point)
     if hit[0] is None:continue
     dot=f.normal.dot(hit[1]);area=f.calc_area()
     if abs(dot)>.6 and hit[3]<.5:vote+=dot*area;weight+=area
   flip=volume<0 if closed else weight>0 and vote/weight<-.35
   if flip:
    bmesh.ops.reverse_faces(bm,faces=shell);reversed_count+=len(shell)
   details.append({'faces':len(shell),'closed':closed,'signed_volume':volume,'reference_vote':vote/max(weight,1e-12),'flipped':flip})
  bm.normal_update();bm.to_mesh(o.data);bm.free()
  if stage=='low' and reversed_count:
   bpy.context.view_layer.objects.active=o
   o.data.normals_split_custom_set_from_vertices([(0,0,0)]*len(o.data.vertices))
   mod=o.modifiers.new('RepairedWeightedNormals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
  rows.append({'name':o.name,'flipped_faces':reversed_count,'shells':details})
 bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{asset}-{stage}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(out/f'{asset}-{stage}.glb'),export_format='GLB',export_materials='NONE' if stage=='high' else 'EXPORT',export_extras=True)
 report['stages'][stage]=rows
(BASE/asset/'orientation-report.json').write_text(json.dumps(report,indent=2));print('ORIENTATION_REPAIRED',asset,{s:sum(r['flipped_faces'] for r in rows) for s,rows in report['stages'].items()})
