"""Determinism, 20 seeds, output isolation, and rejection before publication."""
import json,tempfile,subprocess,sys,hashlib,copy,os
from pathlib import Path
from unittest.mock import patch
import build_whitebox as b
ROOT=b.ROOT;rows=[]
for seed in range(b.DEFAULT_SEED,b.DEFAULT_SEED+20):
 a=b.build(seed);other=b.build(seed);assert a==other
 if all((ROOT/f'assets/environment/{asset}/{asset}.glb').exists() for asset in ['A','B1','B2','C','D','E']):
  final=b.build(seed,'final');assert final==b.build(seed,'final')
  assert all('scripts/module_visual.gd' in value for key,value in final.items() if key.startswith('assets/industrial/'))
 d=json.loads(a['docs/design/energy-layout.json']);rows.append({'seed':seed,**d['validation'],'sha256':hashlib.sha256(a['scenes/training.tscn'].encode()).hexdigest()})
assert len({r['sha256'] for r in rows})==20
assert all(r['thermal_subtypes']=={'B1':6,'B2':6} and r['instances']==59 for r in rows)
bad=copy.deepcopy(d);bad['modules'][1]['position']=bad['modules'][0]['position'][:]
try:b.validate(bad);raise AssertionError('overlap accepted')
except ValueError:pass
with tempfile.TemporaryDirectory() as tmp:
 subprocess.run([sys.executable,str(ROOT/'tools/build_whitebox.py'),'--output-dir',tmp],check=True,capture_output=True)
 dest=Path(tmp)/'scenes/training.tscn';before=dest.read_bytes()
 with patch.object(b,'layout',return_value=bad),patch.object(sys,'argv',['build_whitebox','--output-dir',tmp]):
  try:b.main();raise AssertionError('invalid output accepted')
  except ValueError:pass
 assert dest.read_bytes()==before
 assert not (Path(tmp)/'assets/whitebox').exists()
out=ROOT/os.environ.get('LUNA_QA_OUTPUT','docs/validation/energy-whitebox-v2');out.mkdir(parents=True,exist_ok=True)
(out/'generation.json').write_text(json.dumps({'seeds':rows,'deterministic':True,'different_seeds_vary':True,'invalid_layout_preserves_scene':True,'weapon_generation_isolated':True},indent=2)+'\n')
print('ENERGY_GENERATION_PASS 20 seeds, deterministic output, invalid layout rejected without overwriting')
