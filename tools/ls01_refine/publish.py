"""Enable validated candidate without rewriting the preserved ML06 resources."""
from pathlib import Path
import json,hashlib
from paths import parse
args,R,O,A,D=parse()
for name in ['geometry-audit','runtime-audit','bake-audit','padding-audit']:
 report=json.loads((D/(name+'.json')).read_text());assert not report['failures'],name
assert all(x['passed'] for x in json.loads((D/'ammo-qa.json').read_text()))
assert json.loads((D/'performance-comparison.json').read_text())['within_10_percent']
review=json.loads((D/'visual-review.json').read_text());assert all(x['implementation_review']=='pass' for x in review['issues'])
for logfile in ['rifle/headless.log','rifle/native.log','scene-switch.log',('pbr-capture.log' if args.revision=='ml09' else 'capture.log'),'game.log','lighting.log']:
 text=(D/logfile).read_text();assert not any(x in text for x in ['SCRIPT ERROR','ERROR:','QA FAIL']),logfile
assert 'RIFLE_QA_COMPLETE failures=0' in (D/'rifle/native.log').read_text()
if args.revision=='ml09':
 structure=json.loads((D/'structure-review.json').read_text())
 assert all(x['status']=='pass' for x in structure['features']),'Open structural defect'
 for path,digest in structure['reviewed_hashes'].items():
  assert hashlib.sha256((R/path).read_bytes()).hexdigest()==digest,'Visual evidence is stale: '+path
 assert all(x['passed'] for x in json.loads((D/'spill-controls.json').read_text()))
 assert json.loads((D/'spill-pixels.json').read_text())['passed']
manifest={'revision':args.revision.upper()+' LS01','default_enabled':True,'user_acceptance':'pending','implementation_review':'pass within declared rebuilt scope','concept_equivalence':'open','open_concept_gaps':review['open_concept_gaps'],'assets':{str(p.relative_to(A)):hashlib.sha256(p.read_bytes()).hexdigest() for p in A.rglob('*') if p.suffix in ['.glb','.png','.json']}}
(A/'APPROVED').write_text(json.dumps(manifest,indent=2));print('Published '+args.revision+' candidate; user acceptance remains pending')
