"""Publish one audited candidate. Baselines remain immutable in art_source."""
import json,shutil,argparse
from pathlib import Path
R=Path(__file__).resolve().parents[2];p=argparse.ArgumentParser();p.add_argument('--asset',required=True);a=p.parse_args();A=a.asset
V=R/'docs/validation/environment-refine-v2'/A
for file in [V/'audit.json',V/'candidate/checks.json']:
 d=json.loads(file.read_text());assert d.get('failures',0)==0 and d.get('passed',True),file
S=R/'assets/environment/candidates'/A;D=R/'assets/environment'/A
assert (R/'art_source/environment/refine-v2'/A/'00-baseline').exists()
for f in S.rglob('*'):
 if f.is_file() and f.suffix!='.import':
  target=D/f.relative_to(S);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,target)
print('PUBLISHED',A)
