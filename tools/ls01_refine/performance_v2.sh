#!/bin/zsh
set -eu
cd "${0:A:h:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT=docs/validation/ls01-refine-v2
export LS01_REPORT_DIR="res://$OUT"
for round in 1 2 3 4; do
  phases=(ml07 ml09)
  if (( round % 2 == 0 )); then phases=(ml09 ml07); fi
  for phase in $phases; do
    LS01_PHASE="paired-$phase-$round" "$GODOT" --path . --script tools/ls01_refine/performance.gd -- "--weapon-revision=$phase" > "$OUT/performance-paired-$phase-$round.log" 2>&1
  done
done
python3 - <<'PY'
from pathlib import Path
import json,statistics
p=Path('docs/validation/ls01-refine-v2');d={v:[json.loads((p/f'performance-paired-{v}-{i}.json').read_text()) for i in range(1,5)] for v in ['ml07','ml09']}
a=statistics.median(x['p95_ms'] for x in d['ml07']);b=statistics.median(x['p95_ms'] for x in d['ml09']);d.update(before_p95_median_ms=a,after_p95_median_ms=b,increase_fraction=b/a-1,within_10_percent=b<=a*1.1,order='ABBA ABBA: ML07 vs ML09; 150 warmup + 600 frames; 1600x1000')
(p/'performance-comparison.json').write_text(json.dumps(d,indent=2));print(json.dumps({k:v for k,v in d.items() if k not in ['ml07','ml09']},indent=2))
PY
