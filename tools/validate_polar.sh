#!/bin/zsh
# Headless gameplay; optional serial native route, or paired ML35/current lighting evidence.
set -eu
cd "${0:A:h:h}"
source ./tools/quarantine/check_log.sh
ENGINE="${GODOT_BIN:-}"
if [[ -z "$ENGINE" ]]; then
  for p in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [[ -x "$p" ]]; then ENGINE="$p"; break; fi
  done
fi
if [[ -z "$ENGINE" ]]; then ENGINE="$(command -v godot4 || command -v godot || true)"; fi
[[ -n "$ENGINE" ]] || { print -u2 'Godot 4.7.2 is required'; exit 1; }
mode="${1:---headless}"
case "$mode" in
  --headless|--native|--lighting) ;;
  *) print -u2 'Use --headless, --native or --lighting'; exit 2 ;;
esac
out="${POLAR_QA_OUTPUT:-$PWD/artifacts/polar-$(date +%Y%m%d-%H%M%S)}"
out="${out:A}"
[[ ! -e "$out" ]] || { print -u2 'Use a new POLAR_QA_OUTPUT directory'; exit 2; }
mkdir -p "$out"
"$ENGINE" --headless --path . --editor --import --quit > "$out/import.log" 2>&1
check_log "$out/import.log"
"$ENGINE" --headless --path . --fixed-fps 60 --script res://tools/polar/mission_test.gd -- --polar-qa > "$out/mission.log" 2>&1
check_log "$out/mission.log"
grep -E '^POLAR_TOTAL [0-9]+ checks, 0 failed;' "$out/mission.log"
capture() {
  local dir="$1" profile="$2" count="$3"
  shift 3
  mkdir -p "$dir"
  POLAR_LIGHTING="$profile" POLAR_FRAMES="$dir/frames" "$ENGINE" --path . --rendering-method forward_plus --resolution 1440x900 --fixed-fps 60 --script res://tools/polar/frames.gd -- --polar-qa "$@" > "$dir/frames.log" 2>&1
  check_log "$dir/frames.log"
  [[ "$(grep -c '^POLAR_FRAME .*true' "$dir/frames.log")" == "$count" ]]
}
probe() {
  local prefix="$1" profile="$2"
  POLAR_LIGHTING="$profile" POLAR_NATIVE_REPORT="$prefix.json" "$ENGINE" --path . --rendering-method forward_plus --resolution 1600x900 --script res://tools/polar/native_probe.gd -- --polar-qa > "$prefix.log" 2>&1
  check_log "$prefix.log"
  grep -E '^POLAR_NATIVE ' "$prefix.log"
  [[ -s "$prefix.json" ]]
}
profile="${POLAR_LIGHTING:-enhanced}"
if [[ "$mode" == --native ]]; then
  capture "$out" "$profile" 10
  probe "$out/native" "$profile"
fi
if [[ "$mode" == --lighting ]]; then
  profile=enhanced
  capture "$out" "$profile" 14 --polar-lighting-qa
  grep -x 'POLAR_LIGHT_PROFILE enhanced' "$out/frames.log"
  capture "$out/baseline" baseline 11 --polar-lighting-qa
  grep -x 'POLAR_LIGHT_PROFILE baseline' "$out/baseline/frames.log"
  mkdir -p "$out/performance"
  # Repeat in reverse order to reduce a systematic warm-up/order advantage.
  probe "$out/performance/baseline-1" baseline
  probe "$out/performance/enhanced-1" enhanced
  probe "$out/performance/enhanced-2" enhanced
  probe "$out/performance/baseline-2" baseline
fi
if [[ "$mode" != --headless ]]; then
  POLAR_LIGHTING="$profile" POLAR_ROUTE_OUTPUT="$out/route" "$ENGINE" --path . --rendering-method forward_plus --resolution 1440x900 --fixed-fps 60 --script res://tools/polar/native_route.gd -- --polar-qa > "$out/route.log" 2>&1
  check_log "$out/route.log"
  grep -E '^POLAR_ROUTE true ' "$out/route.log"
fi
print "Polar extraction validation: $out"
