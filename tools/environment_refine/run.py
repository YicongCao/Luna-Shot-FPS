#!/usr/bin/env python3
"""Local-only ML15 stages. Never submits paid remote jobs."""
import argparse,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2];p=argparse.ArgumentParser();p.add_argument('stage',choices=['build','bake','pack','export','audit','interfaces']);p.add_argument('--asset',choices=['B1','B2','C','D','E'],required=True);p.add_argument('--seed',type=int,default=20261116);p.add_argument('--out');p.add_argument('--runtime');a=p.parse_args();O=Path(a.out or R/'art_source/environment/refine-v2'/a.asset);D=Path(a.runtime or R/'assets/environment/candidates'/a.asset)
B='/Applications/Blender.app/Contents/MacOS/Blender'
if a.stage=='pack':cmd=['uv','run','--with','numpy','--with','pillow','python','tools/ls01_refine/pack.py','--group','body','--out',str(O),'--runtime',str(D),'--size','2048']
else:
 extras=['--out',str(O),'--group','body','--resolution','4096'] if a.stage=='bake' else ['--asset',a.asset]
 if a.stage=='build':extras+=['--seed',str(a.seed),'--out',str(O)]
 if a.stage in ['export','audit','interfaces']:extras+=['--out',str(O)]
 if a.stage=='export':extras+=['--runtime',str(D)]
 cmd=[B,'--background','--python-exit-code','1','--python',str(R/'tools/environment_refine'/(a.stage+'.py')),'--',*extras]
subprocess.run(cmd,cwd=R,check=True)
