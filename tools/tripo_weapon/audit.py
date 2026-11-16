"""Inspect remote GLBs without rebuilding geometry or rewriting PBR."""
from pathlib import Path
import json,struct,hashlib
R=Path(__file__).resolve().parents[2];O=R/'art_source/weapons/lc01/tripo-rebuild-v3';D=R/'docs/validation/tripo-weapon-v3';D.mkdir(exist_ok=True)
def inspect(p,stage):
 raw=p.read_bytes();size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size]);start=20+size;binary=raw[start+8:];access=g['accessors'];tri=0;parts=[]
 for m in g.get('meshes',[]):
  count=sum(access[s['indices']]['count']//3 if 'indices' in s else access[s['attributes']['POSITION']]['count']//3 for s in m['primitives'] if s.get('mode',4)==4);tri+=count;parts.append({'name':m.get('name'),'triangles':count})
 maps=[];folder=D/(stage+'-textures');folder.mkdir(exist_ok=True)
 for i,im in enumerate(g.get('images',[])):
  if 'bufferView' not in im:continue
  v=g['bufferViews'][im['bufferView']];offset=v.get('byteOffset',0);blob=binary[offset:offset+v['byteLength']];suffix={'image/png':'png','image/jpeg':'jpg','image/webp':'webp'}.get(im.get('mimeType'),'bin');dest=folder/f'image-{i}.{suffix}';dest.write_bytes(blob);maps.append({'index':i,'mime':im.get('mimeType'),'file':str(dest.relative_to(R)),'sha256':hashlib.sha256(blob).hexdigest()})
 return {'stage':stage,'source':str(p.relative_to(R)),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'triangles':tri,'meshes':parts,'materials':g.get('materials',[]),'textures':g.get('textures',[]),'images':maps,'nodes':[{k:n[k] for k in ['name','mesh','translation','rotation','scale','matrix'] if k in n} for n in g.get('nodes',[])]}
results=[inspect(R/'art_source/weapons/lc01/pipeline-v1/01-tripo-geometry/model.glb','original')]
for stage in ['01-high-pbr','02-low-pbr']:
 if (O/stage/'model.glb').exists():results.append(inspect(O/stage/'model.glb',stage))
(D/'audit.json').write_text(json.dumps(results,indent=2));print([(r['stage'],r['triangles'],len(r['meshes']),len(r['materials'])) for r in results])
