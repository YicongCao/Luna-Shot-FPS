"""Publish one audited candidate. Baselines remain immutable in art_source."""
import json,shutil,argparse
from pathlib import Path
R=Path(__file__).resolve().parents[2];p=argparse.ArgumentParser();p.add_argument('--asset',required=True);p.add_argument('--phase',default='candidate');a=p.parse_args();A=a.asset
V=R/'docs/validation/environment-refine-v2'/A
for file in [V/'audit.json',V/a.phase/'checks.json',V/'performance-comparison.json']:
 d=json.loads(file.read_text());assert d.get('failures',0)==0 and d.get('passed',True),file
perf=json.loads((V/'performance-comparison.json').read_text());assert perf['after']['seconds']>=59.9, 'Requires a full 60 second sample'
if (V/'interfaces.json').exists():assert json.loads((V/'interfaces.json').read_text())['failures']==0
S=R/'assets/environment/candidates'/A;D=R/'assets/environment'/A
binding=json.loads((S/'bindings.json').read_text());assert len(binding['fixtures'].get('mounts',[]))=={'B1':4,'B2':4,'C':4,'D':6,'E':1}[A], 'Missing fixture mounts'
assert (R/'art_source/environment/refine-v2'/A/'00-baseline').exists()
for f in S.rglob('*'):
 if f.is_file() and f.suffix!='.import':
  target=D/f.relative_to(S);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,target)
print('PUBLISHED',A)
