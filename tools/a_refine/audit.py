import bpy,bmesh,numpy as np,json
from pathlib import Path
R=Path(__file__).resolve().parents[2];B=R/'art_source/environment/A-refine-v2';O=R/'docs/validation/A-refine-v2'
bpy.ops.wm.open_mainfile(filepath=str(B/'02-low/A-low.blend'));o=bpy.data.objects['A_low'];uv=o.data.uv_layers.active
N=2048;coverage=np.zeros((N,N),np.uint8);overlaps=0
for f in o.data.polygons:
 pts=np.array([uv.data[i].uv[:] for i in f.loop_indices])*N
 xmin,ymin=np.maximum(0,np.floor(pts.min(0)).astype(int));xmax,ymax=np.minimum(N-1,np.ceil(pts.max(0)).astype(int))
 xx,yy=np.meshgrid(np.arange(xmin,xmax+1)+.5,np.arange(ymin,ymax+1)+.5)
 a,b,c=pts;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
 if abs(den)<1e-12:continue
 u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den;v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den;w=1-u-v
 mask=(u>1e-5)&(v>1e-5)&(w>1e-5);view=coverage[ymin:ymax+1,xmin:xmax+1]
 overlaps+=int(((view>0)&mask).sum());view[mask]+=1
bm=bmesh.new();bm.from_mesh(o.data);open_edges=sum(not e.is_manifold for e in bm.edges);bm.free()
r={'triangles':len(o.data.polygons),'strict_interior_uv_overlap_pixels':overlaps,'uv_coverage_fraction':float((coverage>0).mean()),'non_manifold_edges':open_edges,'uv':json.loads((B/'uv-audit.json').read_text()),'geometry':json.loads((B/'geometry.json').read_text()),'bake':json.loads((B/'03-bake/report.json').read_text())}
assert overlaps==0,overlaps
assert r['uv']['out_of_bounds']==0 and r['uv']['degenerate_uv_triangles']==0
assert r['triangles']<=8000 and r['bake']['completed']
(O/'asset-audit.json').write_text(json.dumps(r,indent=2));print('A_AUDIT',r['triangles'],overlaps,r['uv_coverage_fraction'],open_edges)
