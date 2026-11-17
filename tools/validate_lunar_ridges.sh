#!/bin/zsh
set -eu
cd "${0:A:h:h}"
ENGINE="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="${LUNAR_RIDGES_OUTPUT:-docs/validation/lunar-ridges-v1/recheck}"
mkdir -p "$OUT/terrain"
source ./tools/quarantine/check_log.sh
"$ENGINE" --headless --path . --editor --import --quit > "$OUT/import.log" 2>&1
check_log "$OUT/import.log"
for style in refined ridges; do
  TEST_HORIZON_STYLE="$style" "$ENGINE" --headless --path . --script tools/quarantine/test_lunar_horizon.gd > "$OUT/geometry-$style.log" 2>&1
  check_log "$OUT/geometry-$style.log"
done
HORIZON_SHAPE_OUTPUT="$OUT" "$ENGINE" --headless --path . --script tools/quarantine/test_horizon_shape.gd > "$OUT/shape.log" 2>&1
check_log "$OUT/shape.log"
for style in baseline ridges; do
  QUARANTINE_HORIZON="$style" QUARANTINE_SHADOWS=high HORIZON_CAPTURE_OUTPUT="$OUT/terrain/$style" "$ENGINE" --path . --rendering-method forward_plus --resolution 1920x810 --script tools/quarantine/capture_horizon.gd > "$OUT/terrain/$style.log" 2>&1
  check_log "$OUT/terrain/$style.log"
done
QUARANTINE_HORIZON=ridges QUARANTINE_SHADOWS=high QUARANTINE_BENCHMARK_QA_ROOT="$OUT/validation" ./tools/validate_quarantine_benchmark.sh > "$OUT/validation.log" 2>&1
check_log "$OUT/validation.log"
print "Ridge-preserving terrain validated at $OUT; user art acceptance remains separate."
