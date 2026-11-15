from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image
R=Path(__file__).resolve().parents[2];O=R/'art_source/industrial-wear-v1/06-imagegen';records={}
for kind in ['LC01','Kit']:
 before=np.array(Image.open(O/kind/'NormalGL-before.png').convert('RGB'))
 after=np.array(Image.open(O/kind/'NormalGL-after.png').convert('RGB'))
 records[kind]={'normal_changed_pixels':int(np.any(before!=after,2).sum()),'shape_unchanged':before.shape==after.shape,'normal_mean_abs_byte_change':float(np.abs(before.astype(float)-after).mean())}
 assert records[kind]['normal_changed_pixels']>1000 and records[kind]['shape_unchanged']
 if kind=='LC01':
  classes=np.load(R/'art_source/weapons/lc01/pipeline-v2/07-final/material-masks.npz')['classes'][::-1]
  for cls in [4,5]:
   count=int(np.any(before[classes==cls]!=after[classes==cls],1).sum());records[kind][f'excluded_class_{cls}_changed_pixels']=count
   assert count==0,(cls,count)
old=R/'art_source/industrial-wear-v1/LC01/00-baseline/Emission.png';new=R/'assets/weapons/lc01/Emission.png';assert old.read_bytes()==new.read_bytes();records['emission_unchanged']=True
(R/'docs/validation/industrial-wear-v1/micro-audit.json').write_text(json.dumps(records,indent=2));print(json.dumps(records))
