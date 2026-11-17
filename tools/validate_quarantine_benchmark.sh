#!/bin/zsh
set -eu
cd "${0:A:h:h}"
ENGINE="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="${QUARANTINE_BENCHMARK_QA_ROOT:-docs/validation/quarantine-benchmark-v1}"
export QUARANTINE_BENCHMARK_QA_ROOT="$OUT"
mkdir -p "$OUT"
source ./tools/quarantine/check_log.sh
QUARANTINE_QA_OUTPUT="$OUT/regression" ./tools/validate_quarantine.sh --native > "$OUT/regression.log" 2>&1
check_log "$OUT/regression.log"
"$ENGINE" --path . --rendering-method forward_plus --resolution 1920x810 --script tools/quarantine/test_feedback.gd -- --quarantine-qa > "$OUT/feedback.log" 2>&1
check_log "$OUT/feedback.log"
QUARANTINE_BENCHMARK_OUTPUT="$OUT/native" "$ENGINE" --path . --rendering-method forward_plus --resolution 1920x810 --script tools/quarantine/test_benchmark.gd -- --benchmark-capture > "$OUT/native.log" 2>&1
check_log "$OUT/native.log"
# Performance uses the actual user launcher, without screenshot writes or MovieWriter.
QUARANTINE_BENCHMARK_OUTPUT="$OUT/performance" ./launch-benchmark.command -- --benchmark-qa > "$OUT/performance.log" 2>&1
check_log "$OUT/performance.log"
print "Benchmark, feedback and playable handoff validated: $OUT"
