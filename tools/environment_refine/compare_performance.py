import json,argparse
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--asset',required=True);a=p.parse_args();R=Path(__file__).resolve().parents[2]/'docs/validation/environment-refine-v2';before=json.loads((R/'baseline/performance.json').read_text());after=json.loads((R/a.asset/'performance/performance.json').read_text());increase=after['p95_ms']/before['p95_ms']-1
r={'before':before,'after':after,'p95_increase':increase,'passed':increase<=.10};(R/a.asset/'performance-comparison.json').write_text(json.dumps(r,indent=2));print('PERFORMANCE',a.asset,increase,r['passed']);assert r['passed']
