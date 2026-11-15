import json,sys
from pathlib import Path
asset,stage,task=sys.argv[1:];p=Path(__file__).resolve().parents[2]/'art_source/environment/pipeline-v1/tasks.json';data=json.loads(p.read_text())
if not any(t['task_id']==task for t in data['tasks']):data['tasks'].append(dict(asset=asset,stage=stage,task_id=task))
p.write_text(json.dumps(data,indent=2)+'\n')
