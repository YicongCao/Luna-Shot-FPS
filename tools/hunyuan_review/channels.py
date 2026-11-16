"""Inspect actual GLB channel bindings; preserve embedded images byte-for-byte."""
import json,struct,hashlib
from pathlib import Path
from PIL import Image
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/hunyuan-weapon-v1'
files={'hy-high':'art_source/weapons/lc01/hunyuan-v1/high.glb','hy-low':'art_source/weapons/lc01/hunyuan-v1/low.glb','hy-pbr':'art_source/weapons/lc01/hunyuan-v1/pbr.glb','tripo-high':'art_source/weapons/lc01/tripo-rebuild-v3/01-high-pbr/model.glb','tripo-low':'art_source/weapons/lc01/tripo-rebuild-v3/02-low-pbr/model.glb'}
records=[]
for stage,path in files.items():
 p=R/path;raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);binary=raw[28+n:];a=g['accessors'];tri=sum((a[s['indices']]['count'] if 'indices' in s else a[s['attributes']['POSITION']]['count'])//3 for m in g['meshes'] for s in m['primitives'] if s.get('mode',4)==4)
 images=[]
 for i,im in enumerate(g.get('images',[])):
  v=g['bufferViews'][im['bufferView']];off=v.get('byteOffset',0);blob=binary[off:off+v['byteLength']];ext='png' if im['mimeType']=='image/png' else 'jpg';dest=D/'textures'/stage/f'{i}.{ext}';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(blob)
  img=Image.open(dest);images.append({'index':i,'size':list(img.size),'bytes':len(blob),'file':str(dest.relative_to(D)),'sha256':hashlib.sha256(blob).hexdigest()})
 records.append({'id':stage,'source':path,'bytes':len(raw),'triangles':tri,'mesh_count':len(g['meshes']),'material_count':len(g.get('materials',[])),'materials':g.get('materials',[]),'textures':g.get('textures',[]),'images':images,'texture_bytes':sum(i['bytes'] for i in images),'attributes':[{k:a[v]['count'] for k,v in s['attributes'].items()} for m in g['meshes'] for s in m['primitives']],'generator':g['asset'].get('generator')})
(D/'channels.json').write_text(json.dumps(records,indent=2));print([(r['id'],r['triangles'],r['material_count'],len(r['images'])) for r in records])
