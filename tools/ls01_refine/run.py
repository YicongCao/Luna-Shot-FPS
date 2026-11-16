"""Reproducible staged ML07 entry. Does not publish by default."""
import argparse,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2];B='/Applications/Blender.app/Contents/MacOS/Blender'
p=argparse.ArgumentParser();p.add_argument('stage',choices=['build','bake','export','pack','audit']);p.add_argument('--revision',choices=['ml07','ml09'],default='ml07');p.add_argument('--out');p.add_argument('--runtime');p.add_argument('--size',type=int,default=0);p.add_argument('--report-dir');p.add_argument('--seed',type=int,default=20261115);p.add_argument('--group',choices=['body','kit','all'],default='all');a=p.parse_args()
v='2' if a.revision=='ml09' else '1'
a.out=a.out or str(R/f'art_source/weapons/lc01/ls01-refine-v{v}')
a.runtime=a.runtime or str(R/f'assets/weapons/lc01/ls01_v{v}')
a.report_dir=a.report_dir or str(R/f'docs/validation/ls01-refine-v{v}')
def blender(script,extras=[]):subprocess.run([B,'--background','--python-exit-code','1','--python',str(R/'tools/ls01_refine'/script),'--',*extras],cwd=R,check=True)
if a.stage=='build':blender('build.py',['--out',a.out,'--seed',str(a.seed),'--revision',a.revision])
if a.stage=='bake':
 for group in (['body','kit'] if a.group=='all' else [a.group]):blender('bake.py',['--out',a.out,'--group',group])
if a.stage=='export':blender('export.py',['--out',a.out,'--runtime',a.runtime])
if a.stage=='pack':
 for group in (['body','kit'] if a.group=='all' else [a.group]):subprocess.run(['uv','run','--with','numpy','--with','pillow','python','tools/ls01_refine/pack.py','--group',group,'--out',a.out,'--runtime',a.runtime,'--size',str(a.size)],cwd=R,check=True)
if a.stage=='audit':blender('audit_geometry.py',['--out',a.out,'--report-dir',a.report_dir])
