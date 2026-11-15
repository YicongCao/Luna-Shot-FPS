"""Check 2K atlas island separation using continuous UV island identities."""
from pathlib import Path
import numpy as np,json
from scipy.ndimage import distance_transform_edt
R=Path(__file__).resolve().parents[2];O=R/'art_source/weapons/lc01/ls01-refine-v1';report={};fail=[]
for group in ['body','kit']:
 labels=np.load(O/(group+'-uv-coverage.npz'))['islands'];occupied=labels>0
 distance,indices=distance_transform_edt(~occupied,return_indices=True);near=labels[tuple(indices)];gaps=[]
 for axis in [0,1]:
  s=[slice(None)]*2;t=s.copy();s[axis]=slice(None,-1);t[axis]=slice(1,None);s=tuple(s);t=tuple(t)
  change=(near[s]!=near[t])&(near[s]>0)&(near[t]>0)
  gaps.extend((distance[s][change]+distance[t][change]+1).tolist())
 # Pixel-center approximation has a <=2px raster uncertainty; pack margin is 0.008 per side.
 minimum=min(gaps);report[group]={'islands':int(labels.max()),'minimum_separation_px_at_2k':minimum,'bake_dilation_px_at_2k':16,'raster_uncertainty_px':2,'passed':minimum>=30}
 if minimum<30:fail.append(group)
report['failures']=fail;(R/'docs/validation/ls01-refine-v1/padding-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));assert not fail
