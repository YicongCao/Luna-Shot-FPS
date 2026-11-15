#!/bin/zsh
set -eu
cd "${0:A:h:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
for round in 1 2 3 4; do
  phases=(before after)
  if (( round % 2 == 0 )); then phases=(after before); fi
  for phase in $phases; do
    candidate=0
    baseline=1
    if [[ "$phase" == after ]]; then candidate=1; baseline=0; fi
    LS01_BASELINE="$baseline" LS01_CANDIDATE="$candidate" LS01_PHASE="paired-$phase-$round" "$GODOT" --path . --script tools/ls01_refine/performance.gd > "docs/validation/ls01-refine-v1/performance-paired-$phase-$round.log" 2>&1
  done
done
python3 - <<'PY'
from pathlib import Path
import json,statistics
p=Path('docs/validation/ls01-refine-v1');data={phase:[json.loads((p/f'performance-paired-{phase}-{i}.json').read_text()) for i in [1,2,3,4]] for phase in ['before','after']}
before=statistics.median(d['p95_ms'] for d in data['before']);after=statistics.median(d['p95_ms'] for d in data['after']);data.update({'before_p95_median_ms':before,'after_p95_median_ms':after,'increase_fraction':after/before-1,'within_10_percent':after<=before*1.1,'order':'ABBA ABBA; 4 runs per version; 600 measured + 150 warmup frames each'})
(p/'performance-comparison.json').write_text(json.dumps(data,indent=2));print(json.dumps(data,indent=2))
PY
