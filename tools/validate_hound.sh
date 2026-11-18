#!/bin/zsh
# Sequential native runs: do not start another game window during a capture or timing pass.
set -eu
cd "${0:A:h:h}"
source ./tools/quarantine/check_log.sh
g="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
out="${HOUND_OUTPUT:-$PWD/artifacts/hound-$(date +%Y%m%d-%H%M%S)}"
out="${out:A}"
[[ ! -e "$out" ]] || { print -u2 'Provide a new HOUND_OUTPUT directory.'; exit 1; }
mkdir -p "$out/checks" "$out/gait"
export QUARANTINE_BUG_STYLE=hound
unset QUARANTINE_GAIT
"$g" --headless --path . --editor --import --quit > "$out/import.log" 2>&1
check_log "$out/import.log"
HOUND_CHECKS_OUTPUT="$out/checks" "$g" --headless --fixed-fps 60 --path . --script tools/quarantine/test_hound.gd -- --quarantine-qa > "$out/checks/headless.log" 2>&1
check_log "$out/checks/headless.log"
GAIT_OUTPUT="$out/gait" "$g" --headless --fixed-fps 60 --path . --script tools/quarantine/test_bug_gait.gd > "$out/gait/run.log" 2>&1
check_log "$out/gait/run.log"
for style in refined hound; do
  QUARANTINE_BUG_STYLE=$style HOUND_VIEWS="$out/views" "$g" --path . --rendering-method forward_plus --resolution 1280x720 --fixed-fps 60 --script tools/quarantine/capture_hound.gd -- --quarantine-qa > "$out/$style-views.log" 2>&1
  check_log "$out/$style-views.log"
  QUARANTINE_BUG_STYLE=$style QUARANTINE_UNCAPPED=1 QUARANTINE_PERFORMANCE_OUTPUT="$out/active-$style" "$g" --path . --rendering-method forward_plus --resolution 1920x810 --script tools/quarantine/performance.gd -- --quarantine-qa > "$out/active-$style.log" 2>&1
  check_log "$out/active-$style.log"
done
BENCHMARK_LENS_OUTPUT="$out/closeup" "$g" --path . --rendering-method forward_plus --resolution 1920x810 --script tools/quarantine/test_benchmark_lens.gd -- --quarantine-qa > "$out/closeup.log" 2>&1
check_log "$out/closeup.log"
QUARANTINE_BENCHMARK_QA_ROOT="$out/validation" ./tools/validate_quarantine_benchmark.sh
print "Hound checks complete: $out"
