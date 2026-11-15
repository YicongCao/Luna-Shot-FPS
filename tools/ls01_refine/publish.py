"""Enable validated candidate without rewriting the preserved ML06 resources."""
from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/ls01-refine-v1';A=R/'assets/weapons/lc01/ls01_v1'
for name in ['geometry-audit','runtime-audit','bake-audit','padding-audit']:
 report=json.loads((D/(name+'.json')).read_text());assert not report['failures'],name
assert all(x['passed'] for x in json.loads((D/'ammo-qa.json').read_text()))
assert json.loads((D/'performance-comparison.json').read_text())['within_10_percent']
review=json.loads((D/'visual-review.json').read_text());assert all(x['implementation_review']=='pass' for x in review['issues'])
for logfile in ['rifle/headless.log','rifle/native.log','scene-switch.log','capture.log','game.log','lighting.log']:
 text=(D/logfile).read_text();assert not any(x in text for x in ['SCRIPT ERROR','ERROR:','QA FAIL']),logfile
assert 'RIFLE_QA_COMPLETE failures=0' in (D/'rifle/native.log').read_text()
manifest={'revision':'ML07 LS01','default_enabled':True,'user_acceptance':'pending','implementation_review':'pass within declared rebuilt scope','concept_equivalence':'open','open_concept_gaps':review['open_concept_gaps'],'assets':{str(p.relative_to(A)):hashlib.sha256(p.read_bytes()).hexdigest() for p in A.rglob('*') if p.suffix in ['.glb','.png','.json']}}
(A/'APPROVED').write_text(json.dumps(manifest,indent=2));print('Published ML07 candidate; user acceptance remains pending')
