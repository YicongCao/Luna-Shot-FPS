"""Pack baked linear channels into ORM, normalized 2K tangent normals; source 4K retained."""
from pathlib import Path
from PIL import Image
import numpy as np,json,shutil,argparse
R=Path(__file__).resolve().parents[2];O=R/'art_source/weapons/lc01/ls01-refine-v1';D=R/'assets/weapons/lc01/ls01_v1'
a=argparse.ArgumentParser();a.add_argument('--group',choices=['body','kit'],required=True);a.add_argument('--size',type=int,default=0);a.add_argument('--out',default=str(O));a.add_argument('--runtime',default=str(D));args=a.parse_args();O=Path(args.out);D=Path(args.runtime);D.mkdir(parents=True,exist_ok=True);profile=D/'resolution.json';explicit_size=args.size;args.size=args.size or (json.loads(profile.read_text()).get(args.group,2048) if profile.exists() else 2048);src=O/'03-bake'/args.group;dst=D/args.group;dst.mkdir(exist_ok=True)
assert not (D/'APPROVED').exists(),'Active validated runtime is protected: choose a new --runtime directory'
report=json.loads((src/'report.json').read_text())
assert report.get('completed'), 'Bake is not complete; wait for both atlas groups before packing'
for name in ['BaseColor','AO','Roughness','Metallic','NormalGL']:
 p=src/(name+'.png')
 assert p.exists(),p
 size=args.size
 if name=='NormalGL' and not explicit_size and profile.exists():size=json.loads(profile.read_text()).get(args.group+'_normal',size)
 im=Image.open(p).convert('RGB').resize((size,size),Image.Resampling.LANCZOS)
 if name=='NormalGL':
  ar=np.asarray(im).astype(float)/127.5-1;ar/=np.maximum(np.linalg.norm(ar,axis=-1,keepdims=True),1e-6);im=Image.fromarray(np.uint8(np.clip((ar+1)*127.5,0,255)))
 im.save(dst/(name+'.png'))
channels=[Image.open(dst/(name+'.png')).convert('L') for name in ['AO','Roughness','Metallic']];Image.merge('RGB',channels).save(dst/'ORM.png')
print('PACKED',args.group,args.size)
