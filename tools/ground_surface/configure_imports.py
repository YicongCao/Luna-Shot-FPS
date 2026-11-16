from pathlib import Path
R=Path(__file__).resolve().parents[2]/'assets/environment/ground_v1'
for kind in ['paving','regolith','metal']:
 for p in (R/kind).glob('*.png.import'):
  s=p.read_text().replace('mipmaps/generate=false','mipmaps/generate=true').replace('compress/mode=0','compress/mode=2')
  if p.name=='NormalGL.png.import':s=s.replace('compress/normal_map=0','compress/normal_map=1')
  s=s.replace('process/normal_map_invert_y=true','process/normal_map_invert_y=false');p.write_text(s)
print('GROUND_IMPORT_PROFILE GPU compression / mipmaps / GL normals')
