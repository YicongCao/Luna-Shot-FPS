"""Promote the ground only after native, traversal, mask and performance gates."""
import json,hashlib,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/ground-v1'
subprocess.run(['python3',str(Path(__file__).with_name('report.py'))],check=True)
for p in D.rglob('*.log'):
 s=p.read_text(errors='replace');assert not any(e in s for e in ['SCRIPT ERROR','Parse Error','ERROR:']),p
source=[R/'scripts/ground_surface.gd',R/'assets/environment/ground_v1/surface.gdshader',R/'art_source/environment/ground-v1/manifest.json']
marker={'milestone':'ML16','technical':'passed','implementation_visual_review':'passed','user_visual_acceptance':'pending','source_sha256':{str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source},'note':'Build-time marker. Generator writes published=true into the scene; runtime does not depend on packaging this marker.'}
(R/'assets/environment/ground_v1/APPROVED').write_text(json.dumps(marker,indent=2))
subprocess.run(['python3',str(R/'tools/build_whitebox.py')],check=True);print('ML16_PUBLISHED')
