"""Read-only face-corner correspondence gate for the ML19 texture-only trial.
Usage: uv run --with numpy --with scipy --with pillow python tools/hunyuan_pbr/audit.py
Vertex/index reordering is allowed; winding, surface positions, UV and normals are checked.
"""
from pathlib import Path
import hashlib,json,struct
import numpy as np
from scipy.spatial import cKDTree
from PIL import Image
R=Path(__file__).resolve().parents[2];S=R/'art_source/weapons/lc01/hunyuan-tripo-pbr-v1';D=R/'docs/validation/hunyuan-tripo-pbr-v1';D.mkdir(parents=True,exist_ok=True)
class GLB:
 def __init__(self,path):
  self.path=path;self.raw=path.read_bytes();assert self.raw[:4]==b'glTF';n=struct.unpack_from('<I',self.raw,12)[0];self.g=json.loads(self.raw[20:20+n]);self.blob=self.raw[28+n:]
 def accessor(self,i):
  a=self.g['accessors'][i];assert 'sparse' not in a and not a.get('normalized',False)
  v=self.g['bufferViews'][a['bufferView']];dt={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];cols={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];item=np.dtype(dt).itemsize
  return np.ndarray((a['count'],cols),dtype=dt,buffer=self.blob,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',item*cols),item)).copy()
 def mesh(self):
  assert len(self.g['meshes'])==1 and len(self.g['meshes'][0]['primitives'])==1
  assert len(self.g['nodes'])==1 and not any(k in self.g['nodes'][0] for k in ['translation','rotation','scale','matrix']), 'Node transform needs explicit audit'
  p=self.g['meshes'][0]['primitives'][0];assert p.get('mode',4)==4
  return {k:self.accessor(v).astype(float) for k,v in p['attributes'].items()},self.accessor(p['indices']).reshape(-1,3)
 def textures(self,stage):
  maps=[]
  for i,im in enumerate(self.g.get('images',[])):
   v=self.g['bufferViews'][im['bufferView']];offset=v.get('byteOffset',0);data=self.blob[offset:offset+v['byteLength']];suffix={'image/png':'png','image/jpeg':'jpg','image/webp':'webp'}[im['mimeType']];p=D/'textures'/stage/f'{i}.{suffix}';p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
   with Image.open(p) as img:
    arr=np.asarray(img.convert('RGB'));stats=[{'min':int(arr[:,:,c].min()),'max':int(arr[:,:,c].max()),'mean':float(arr[:,:,c].mean()),'std':float(arr[:,:,c].std())} for c in range(3)];size=list(img.size)
   maps.append({'index':i,'path':str(p.relative_to(D)),'size':size,'sha256':hashlib.sha256(data).hexdigest(),'channels':stats})
  return {'source':str(self.path.relative_to(R)),'bytes':len(self.raw),'sha256':hashlib.sha256(self.raw).hexdigest(),'materials':self.g.get('materials',[]),'textures':self.g.get('textures',[]),'images':maps}
def compare(a,ai,b,bi,scale,center):
 """Match face centroids, then cyclic (not reversed) corners. Units are original GLB units."""
 ap=a['POSITION'][ai];bp=(b['POSITION']/scale+center)[bi]
 count_ok=len(ai)==len(bi);tree=cKDTree(bp.mean(1));dist,idx=tree.query(ap.mean(1),k=min(8,len(bi)))
 if idx.ndim==1:idx=idx[:,None]
 used=set();matches=[];max_pos=0.;miss=0
 for i,tri in enumerate(ap):
  best=None
  for j in idx[i]:
   if int(j) in used:continue
   for shift in range(3):
    p=np.roll(bp[j],-shift,axis=0);err=float(np.max(np.linalg.norm(p-tri,axis=1)))
    if best is None or err<best[0]:best=(err,int(j),shift)
  if best is None or best[0]>2e-6:miss+=1;continue
  err,j,shift=best;used.add(j);matches.append((i,j,shift));max_pos=max(max_pos,err)
 uv_errors=[];normal_errors=[]
 for i,j,shift in matches:
  for name,errors in [('TEXCOORD_0',uv_errors),('NORMAL',normal_errors)]:
   errors.extend(np.linalg.norm(a[name][ai[i]]-np.roll(b[name][bi[j]],-shift,axis=0),axis=1).tolist())
 def stat(errors,tol):return {'max':max(errors,default=None),'mean':float(np.mean(errors)) if errors else None,'corners_above_tolerance':sum(x>tol for x in errors),'tolerance':tol}
 return {'same_triangle_count':count_ok,'matched_oriented_faces':len(matches),'unmatched_source_faces':miss,'unmatched_output_faces':len(bi)-len(used),'position_max_error_after_service_normalization':max_pos,'position_tolerance':2e-6,'geometry_preserved':count_ok and len(matches)==len(ai),'uv':stat(uv_errors,2e-6),'normals':stat(normal_errors,2e-5),'face_map':matches}
def main():
 src=GLB(R/'art_source/weapons/lc01/hunyuan-v1/pbr.glb');out=GLB(S/'01-tripo/model.glb');a,ai=src.mesh();b,bi=out.mesh();task=json.loads((S/'task.json').read_text());scale=task['normalize_scale'];center=(a['POSITION'].min(0)+a['POSITION'].max(0))*.5
 result=compare(a,ai,b,bi,scale,center);matches=result.pop('face_map')
 x=np.concatenate([a['NORMAL'][ai[i]] for i,j,k in matches]);y=np.concatenate([np.roll(b['NORMAL'][bi[j]],-k,axis=0) for i,j,k in matches]);lx=np.linalg.norm(x,axis=1);ly=np.linalg.norm(y,axis=1);valid=(lx>1e-8)&(ly>1e-8)
 angles=np.degrees(np.arccos(np.clip(np.sum(x[valid]/lx[valid,None]*y[valid]/ly[valid,None],axis=1),-1,1)))
 result['normal_direction_analysis']={'source_zero_length_corners':int(sum(lx<1e-8)),'output_zero_length_corners':int(sum(ly<1e-8)),'valid_direction_corners':int(sum(valid)),'angle_degrees_max':float(angles.max()),'angle_degrees_p50_p95_p99':np.percentile(angles,[50,95,99]).tolist(),'corners_angle_over_0_1_degrees':int(sum(angles>.1)),'note':'Most differences are small normalization/precision changes, but six nonzero-normal corners differ materially; 18 zero normals were replaced. Not byte-identical normals.'}

 result.update({'source_vertices':len(a['POSITION']),'output_vertices':len(b['POSITION']),'source_triangles':len(ai),'output_triangles':len(bi),'service_normalize_scale':scale,'source_bounds_center':center.tolist(),'normalization_note':'Service centers the source bounding box and uniformly scales it; comparison explicitly reverses recorded service scale, no shape fitting/remeshing.','input_sha256':hashlib.sha256(src.raw).hexdigest(),'output_sha256':hashlib.sha256(out.raw).hexdigest()})
 baseline=json.loads((R/'docs/design/ml19/input-baseline.json').read_text());result['source_unchanged']=result['input_sha256']==baseline['sha256'];result['uv_preserved']=result['geometry_preserved'] and result['uv']['corners_above_tolerance']==0;result['normals_preserved']=result['geometry_preserved'] and result['normals']['corners_above_tolerance']==0
 mats=out.g['materials'];result['pbr_bindings_present']=all('normalTexture' in m and all(k in m.get('pbrMetallicRoughness',{}) for k in ['baseColorTexture','metallicRoughnessTexture']) for m in mats)
 result['geometry_uv_gate_passed']=result['source_unchanged'] and result['geometry_preserved'] and result['uv_preserved'];result['all_input_surface_data_preserved']=result['geometry_uv_gate_passed'] and result['normals_preserved']
 channels=[src.textures('original'),out.textures('tripo')];(D/'channels.json').write_text(json.dumps(channels,indent=2));(D/'audit.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
