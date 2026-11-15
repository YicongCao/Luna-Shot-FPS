"""Godot texture sidecars: mipmaps and unambiguous normal interpretation."""
from pathlib import Path
R=Path(__file__).resolve().parents[2];D=R/'assets/weapons/lc01/ls01_v1'
for p in D.rglob('*.png.import'):
 s=p.read_text().replace('mipmaps/generate=false','mipmaps/generate=true')
 if p.name=='NormalGL.png.import':s=s.replace('compress/normal_map=0','compress/normal_map=1')
 s=s.replace('compress/mode=0','compress/mode=2')
 s=s.replace('process/normal_map_invert_y=true','process/normal_map_invert_y=false')
 p.write_text(s)
