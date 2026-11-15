import bpy,numpy as np,json,hashlib,struct
from pathlib import Path
R=Path(__file__).resolve().parents[2];out=R/'docs/validation/industrial-wear-v1';report={}
def inspect(path):
 bpy.ops.wm.open_mainfile(filepath=str(path));result={}
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  uv=np.array([v.uv[:] for v in o.data.uv_layers.active.data],dtype=np.float32);faces=np.array([list(f.vertices) for f in o.data.polygons],dtype=np.int32)
  result[o.name]={'uv_hash':hashlib.sha256(uv.tobytes()).hexdigest(),'indices_hash':hashlib.sha256(faces.tobytes()).hexdigest(),'triangles':len(faces),'uv_oob':int(((uv<0)|(uv>1)).any(1).sum())}
 return result
old=inspect(R/'art_source/weapons/lc01/pipeline-v2/04-low/lc01-low.blend');new=inspect(R/'art_source/weapons/lc01/industrial-wear-v1/04-low/lc01-low.blend');assert old==new;report['rifle_original_uv_and_topology_preserved']=True;report['rifle_parts']=new
old=inspect(R/'art_source/environment/A-refine-v2/02-low/A-low.blend');new=inspect(R/'art_source/industrial-wear-v1/A/02-low/A-low.blend');assert old==new;report['A_original_uv_topology_preserved']=True
report['kit']=inspect(R/'art_source/industrial-wear-v1/Kit/02-low/A-low.blend');assert all(v['uv_oob']==0 for v in report['kit'].values())
p=R/'art_source/industrial-wear-v1/00-tripo/model.glb';raw=p.read_bytes();expected=struct.unpack_from('<III',raw)[2];assert expected==len(raw);report['tripo_download']={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'valid_glb_length':True}
(out/'asset-audit.json').write_text(json.dumps(report,indent=2));print('FIELD_KIT_ASSET_AUDIT_PASS')
