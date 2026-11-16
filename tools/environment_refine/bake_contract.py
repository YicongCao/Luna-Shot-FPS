"""Fail fast if cached master maps refer to a different source or bake contract."""
import hashlib,json
from pathlib import Path

def source_digest(source):return hashlib.sha256(Path(source).read_bytes()).hexdigest()
def check(folder,source,resolution):
 p=Path(folder)/'contract.json';data={'source_sha256':source_digest(source),'resolution':resolution,'normal':'OpenGL +Y','explicit_cage':True,'margin_px':32 if resolution==4096 else 16}
 if p.exists():
  assert json.loads(p.read_text())==data,'Source changed: archive/remove this bake directory before rebuilding'
 else:p.write_text(json.dumps(data,indent=2))
 return data
