#!/bin/zsh
# Headless gameplay is required; native composition and performance are optional and serial.
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
[[ "$mode" == --headless || "$mode" == --native ]] || { print -u2 'Use --headless or --native'; exit 2; }
out="${POLAR_QA_OUTPUT:-$PWD/artifacts/polar-$(date +%Y%m%d-%H%M%S)}"
out="${out:A}"
[[ ! -e "$out" ]] || { print -u2 'Use a new POLAR_QA_OUTPUT directory'; exit 2; }
mkdir -p "$out"
"$ENGINE" --headless --path . --editor --import --quit > "$out/import.log" 2>&1
check_log "$out/import.log"
"$ENGINE" --headless --path . --fixed-fps 60 --script res://tools/polar/mission_test.gd -- --polar-qa > "$out/mission.log" 2>&1
check_log "$out/mission.log"
grep -E '^POLAR_TOTAL [0-9]+ checks, 0 failed;' "$out/mission.log"
if [[ "$mode" == --native ]]; then
  POLAR_FRAMES="$out/frames" "$ENGINE" --path . --rendering-method forward_plus --resolution 1440x900 --fixed-fps 60 --script res://tools/polar/frames.gd -- --polar-qa > "$out/frames.log" 2>&1
  check_log "$out/frames.log"
  [[ "$(grep -c '^POLAR_FRAME .*true' "$out/frames.log")" == 10 ]]
  POLAR_NATIVE_REPORT="$out/native.json" "$ENGINE" --path . --rendering-method forward_plus --resolution 1600x900 --script res://tools/polar/native_probe.gd -- --polar-qa > "$out/native.log" 2>&1
  check_log "$out/native.log"
  grep -E '^POLAR_NATIVE ' "$out/native.log"
  POLAR_ROUTE_OUTPUT="$out/route" "$ENGINE" --path . --rendering-method forward_plus --resolution 1440x900 --fixed-fps 60 --script res://tools/polar/native_route.gd -- --polar-qa > "$out/route.log" 2>&1
  check_log "$out/route.log"
  grep -E '^POLAR_ROUTE true ' "$out/route.log"
fi
print "Polar extraction validation: $out"
