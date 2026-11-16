"""ML09 feature inventory and geometric mounting bounds, executed in Blender."""
import bpy,json,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2];O=R/'art_source/weapons/lc01/ls01-refine-v2';D=R/'docs/validation/ls01-refine-v2'
bpy.ops.wm.open_mainfile(filepath=str(O/'02-geometry/paired.blend'))
m=json.loads((O/'manifest.json').read_text());names=[p['name'] for p in m['pairs']];checks=[]
def check(name,ok,detail):checks.append({'check':name,'passed':bool(ok),'detail':detail})
for prefix,count in [('OpticMountRearFin',3),('OpticMountFrontFin',3),('Cell_TopCover',3),('Cell_LatchSeat',2),('Cell_LatchNotch',2),('StockJointInsert',2),('StockJointTongue',2),('ShroudRib',6),('ShroudInnerRail',2),('ShroudBolt',8)]:
 actual=sum(n.startswith(prefix) for n in names);check(prefix,actual==count,{'expected':count,'actual':actual})
s=json.loads((O/'screen.json').read_text());poly=s['contour'];ys=[p[1] for p in poly];lo=min(ys);hi=max(ys);tip=min(poly,key=lambda p:p[0]);ratio=(tip[1]-lo)/(hi-lo)
check('lower outward screen vertices',abs(ratio-.2)<1e-6,ratio)
check('screen symmetric left/right',all(any(abs(x+xx)<1e-8 and abs(y-yy)<1e-8 for xx,yy in poly) for x,y in poly),poly)
# Source real broad facet projected width: explicit z-varying cross section, not atlas trick.
o=bpy.data.objects['T08_StockShell_low'];pts=[v.co for v in o.data.vertices]
check('stock real broad chamfer band',any(.027<abs(p.x)<.032 and p.z>.100 for p in pts) and any(abs(p.x)>.037 and .085<p.z<.094 for p in pts),{'vertices':len(pts)})
# Optical aperture remains clear at existing red-dot axis in x/z; front/rear fins below it.
for prefix in ['OpticMountRearFin','OpticMountFrontFin']:
 maximum=max(v.co.z for o in bpy.context.scene.objects if o.name.startswith(prefix) and o.name.endswith('_low') for v in o.data.vertices)
 check(prefix+' below ADS axis',maximum<.15,maximum)
check('full static budget plus dynamic allowance',m['runtime_triangles']+400<=60000,m['runtime_triangles']+400)
report={'checks':checks,'passed':all(c['passed'] for c in checks),'note':'Numeric structure checks supplement native grey and PBR screenshots; not visual acceptance.'};(D/'structure-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));assert report['passed']
