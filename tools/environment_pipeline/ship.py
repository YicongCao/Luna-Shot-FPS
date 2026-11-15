import json,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];asset=sys.argv[-1];src=ROOT/'art_source/environment/pipeline-v1'/asset/'07-final';dst=ROOT/'assets/environment'/asset;dst.mkdir(parents=True,exist_ok=True)
report=json.loads((src/'material-transfer-report.json').read_text());assert report['unmatched_triangles']==0
shutil.copy2(src/f'{asset}-final.glb',dst/f'{asset}.glb')
for name in ['BaseColor','NormalGL','ORM','Emission']:shutil.copy2(src/'textures'/f'{name}.png',dst/f'{name}.png')
(dst/'provenance.json').write_text(json.dumps({'source':str(src.relative_to(ROOT)),'triangles':report['final_triangles'],'normal':'genuine high-to-low Cycles bake','asset':asset},indent=2))
print('SHIPPED',asset,report['final_triangles'])
