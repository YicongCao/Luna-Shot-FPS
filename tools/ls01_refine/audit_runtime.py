from pathlib import Path
import json,struct,hashlib,numpy as np
from paths import parse
args,R,O,D,REPORT=parse()
def load(path):
 data=path.read_bytes();off=12;doc=None;binary=None
 while off<len(data):
  size,kind=struct.unpack_from('<II',data,off);raw=data[off+8:off+8+size];off+=size+8
  if kind==0x4e4f534a:doc=json.loads(raw)
  if kind==0x004e4942:binary=raw
 def accessor(i):
  a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];dt=np.dtype(dtype);start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',width*dt.itemsize)
  return np.ndarray((a['count'],width),dtype=dt,buffer=binary,offset=start,strides=(stride,dt.itemsize)).copy()
 result={}
 for node in doc['nodes']:
  if 'mesh' not in node:continue
  mesh=doc['meshes'][node['mesh']];rows=[];tangents=True
  for prim in mesh['primitives']:
   pos=accessor(prim['attributes']['POSITION']);uv=accessor(prim['attributes']['TEXCOORD_0']);ind=accessor(prim['indices']).ravel();tangents &= 'TANGENT' in prim['attributes']
   for tri in ind.reshape(-1,3):rows.append(sorted(tuple(np.round(np.r_[pos[i],uv[i]],6)) for i in tri))
  result[node['name']]={'triangles':sorted(rows),'has_tangents':tangents}
 return result
old=load(O/'00-baseline/lc01/lc01.glb');new=load(D/'weapon.glb');bindings=json.loads((D/'bindings.json').read_text());records={};fail=[]
for name,b in bindings.items():
 if not b['retained']:continue
 # glTF exporter may sanitize a period in names; use equivalent source identifier.
 key=next(k for k in old if k.replace('.','_')==name)
 equal=old[key]['triangles']==new[name]['triangles'];records[name]={'geometry_and_uv_equal':equal,'tangents_exported':new[name]['has_tangents']}
 if not equal:fail.append(name)
if any(not v['has_tangents'] for v in new.values()):fail.append('missing_tangents')
if sum(len(v['triangles']) for v in new.values())>60000:fail.append('triangle_budget')
base=json.loads((O/'00-baseline/hashes.json').read_text());envsame=all(hashlib.sha256((R/p).read_bytes()).hexdigest()==h for p,h in base.items() if p.startswith(('assets/environment/','assets/industrial/')))
if not envsame:fail.append('environment_changed')
report={'retained':records,'environment_unchanged':envsame,'triangles':sum(len(v['triangles']) for v in new.values()),'meshes':len(new),'failures':fail};(REPORT/'runtime-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
assert not fail
