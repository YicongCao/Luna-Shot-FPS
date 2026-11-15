import bpy,bmesh,json,numpy as np,argparse,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2];a=argparse.ArgumentParser();a.add_argument('--out',default=str(R/'art_source/weapons/lc01/ls01-refine-v1'));a.add_argument('--report-dir',default=str(R/'docs/validation/ls01-refine-v1'));args=a.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);O=Path(args.out);REPORT=Path(args.report_dir);REPORT.mkdir(parents=True,exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(O/'02-geometry/paired.blend'))
m=json.loads((O/'manifest.json').read_text());records=[];failed=[]
for p in m['pairs']:
 lo=bpy.data.objects[p['low']];hi=bpy.data.objects[p['high']];c=bpy.data.objects[p['cage']]
 bm=bmesh.new();bm.from_mesh(lo.data);open_edges=sum(not e.is_manifold for e in bm.edges);degenerate=sum(f.calc_area()<1e-14 for f in bm.faces);volume=bm.calc_volume(signed=True);bm.free()
 hb=bmesh.new();hb.from_mesh(hi.data);high_bad=sum(not e.is_manifold for e in hb.edges);high_volume=hb.calc_volume(signed=True);hb.free()
 uv=np.array([x.uv[:] for x in lo.data.uv_layers.active.data]);same=[tuple(f.vertices) for f in lo.data.polygons]==[tuple(f.vertices) for f in c.data.polygons]
 rec={'part':p['name'],'triangles':len(lo.data.polygons),'high_polygons':len(hi.data.polygons),'high_nonmanifold_edges':high_bad,'high_signed_volume':high_volume,'open_or_nonmanifold_edges':open_edges,'degenerate_faces':degenerate,'signed_volume':volume,'uv_in_range':bool(uv.min()>=0 and uv.max()<=1),'cage_matches_topology':same};records.append(rec)
 if high_bad or high_volume<=0 or open_edges or degenerate or volume<=0 or not rec['uv_in_range'] or not same:failed.append(p['name'])
# Rasterize strict interiors, excluding numerical/shared-edge contacts.
for atlas in ['body','kit']:
 N=2048;owners=np.full((N,N),-1,np.int32);islands=np.zeros((N,N),np.int32);next_island=1;overlaps=0;coverage=0
 for index,p in enumerate(m['pairs']):
  if p['group']!=atlas:continue
  lo=bpy.data.objects[p['low']]
  # Identify continuous UV islands from shared UV edges, not disconnected raster slivers.
  parent=list(range(len(lo.data.polygons)));edges={}
  def root(i):
   while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
   return i
  for f in lo.data.polygons:
   uv=[tuple(round(float(v),7) for v in lo.data.uv_layers.active.data[i].uv) for i in f.loop_indices]
   for a,b in zip(uv,uv[1:]+uv[:1]):
    key=tuple(sorted([a,b]))
    if key in edges:parent[root(f.index)]=root(edges[key])
    else:edges[key]=f.index
  ids={}
  for f in lo.data.polygons:
   k=root(f.index)
   if k not in ids:ids[k]=next_island;next_island+=1
  for face in lo.data.polygons:
   uv=np.array([lo.data.uv_layers.active.data[i].uv for i in face.loop_indices])*N-.5;a,b,c=uv;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
   if abs(den)<1e-8:continue
   mn=np.maximum(np.floor(uv.min(0)).astype(int),0);mx=np.minimum(np.ceil(uv.max(0)).astype(int),N-1);xx,yy=np.meshgrid(np.arange(mn[0],mx[0]+1),np.arange(mn[1],mx[1]+1));w0=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den;w1=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den;inside=(w0>.0001)&(w1>.0001)&(1-w0-w1>.0001);x=xx[inside];y=yy[inside];overlaps+=int(np.count_nonzero(owners[y,x]>=0));owners[y,x]=index;islands[y,x]=ids[root(face.index)]
 np.savez_compressed(O/(atlas+'-uv-coverage.npz'),owners=owners,islands=islands)
 m[atlas+'_uv']={'strict_overlap_pixels':overlaps,'coverage':float(np.mean(owners>=0))}
 if overlaps:failed.append(atlas+'_uv_overlap')
report={'parts':records,'atlases':{k:m[k] for k in ['body_uv','kit_uv']},'failures':failed,'completed':not failed}
(REPORT/'geometry-audit.json').write_text(json.dumps(report,indent=2));print('AUDIT',failed)
