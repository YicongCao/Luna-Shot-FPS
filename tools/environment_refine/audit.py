import bpy,bmesh,numpy as np,json,sys,argparse,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[2];a=argparse.ArgumentParser();a.add_argument('--asset',required=True);a.add_argument('--out');a.add_argument('--runtime');args=a.parse_args(sys.argv[sys.argv.index('--')+1:]);A=args.asset;O=Path(args.out or R/'art_source/environment/refine-v2'/A);D=R/'docs/validation/environment-refine-v2'/A;D.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O/'02-geometry/paired.blend'));m=json.loads((O/'manifest.json').read_text());coverage=np.zeros((2048,2048),np.uint8);overlap=degenerate=oob=open_edges=bad_cage=0
for pair in m['pairs']:
 lo=bpy.data.objects[pair['low']];ca=bpy.data.objects[pair['cage']];uv=lo.data.uv_layers.active
 bad_cage+=int(len(lo.data.vertices)!=len(ca.data.vertices) or [tuple(p.vertices) for p in lo.data.polygons]!=[tuple(p.vertices) for p in ca.data.polygons])
 bm=bmesh.new();bm.from_mesh(lo.data);open_edges+=sum(not e.is_manifold for e in bm.edges);bm.free()
 for f in lo.data.polygons:
  pts=np.array([uv.data[i].uv[:] for i in f.loop_indices]);oob+=int(pts.min()<0 or pts.max()>1);pts*=2048
  mn=np.maximum(0,np.floor(pts.min(0)).astype(int));mx=np.minimum(2047,np.ceil(pts.max(0)).astype(int));a,b,c=pts;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
  if abs(den)<1e-9:degenerate+=1;continue
  xx,yy=np.meshgrid(np.arange(mn[0],mx[0]+1)+.5,np.arange(mn[1],mx[1]+1)+.5);u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den;v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
  mask=(u>1e-5)&(v>1e-5)&(1-u-v>1e-5);view=coverage[mn[1]:mx[1]+1,mn[0]:mx[0]+1];overlap+=int(((view>0)&mask).sum());view[mask]+=1
report={'asset':A,'triangles':m['triangles'],'high_triangles':m['high_triangles'],'pairs':len(m['pairs']),'non_manifold_edges':open_edges,'degenerate_uv_triangles':degenerate,'uv_oob':oob,'overlap_pixels':overlap,'coverage':float((coverage>0).mean()),'cage_mismatch':bad_cage,'bake':json.loads((O/'03-bake/body/report.json').read_text())}
report['passed']=not any([open_edges,degenerate,oob,overlap,bad_cage]) and report['bake']['completed'];(D/'audit.json').write_text(json.dumps(report,indent=2));print('ENV_AUDIT',json.dumps({k:v for k,v in report.items() if k!='bake'}));assert report['passed']
