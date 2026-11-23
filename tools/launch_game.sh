#!/bin/zsh
# Shared macOS launcher. Optional GODOT_BIN overrides automatic discovery.
set -eu
PROJECT_ROOT="${0:A:h:h}"
MODE="${1:-polar}"
if (( $# > 0 )); then shift; fi
cd "$PROJECT_ROOT"

if [[ -n "${GODOT_BIN:-}" ]]; then
  ENGINE="$GODOT_BIN"
else
  ENGINE=""
  for candidate in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [[ -x "$candidate" ]]; then ENGINE="$candidate"; break; fi
  done
  if [[ -z "$ENGINE" ]]; then
    ENGINE="$(command -v godot4 || command -v godot || true)"
  fi
fi
if [[ -z "$ENGINE" || ! -x "$ENGINE" ]]; then
  print -u2 '未找到 Godot。请安装 Godot 4.7 或更高版本，或将 GODOT_BIN 设为 Godot 可执行文件的完整路径。'
  exit 1
fi
case "$MODE" in
  polar) SCENE='res://scenes/polar_extraction.tscn' ;;
  training) SCENE='res://scenes/training.tscn' ;;
  lab) SCENE='res://scenes/weapon_lab.tscn' ;;
  ground) SCENE='res://scenes/ground_studio.tscn' ;;
  quarantine) SCENE='res://scenes/quarantine.tscn' ;;
  benchmark) SCENE='res://scenes/quarantine_benchmark.tscn' ;;
  *) print -u2 "未知启动模式：$MODE（可用 polar / training / lab / ground / quarantine / benchmark）"; exit 2 ;;
esac

mkdir -p artifacts/launch
IMPORT_LOG="$PROJECT_ROOT/artifacts/launch/import.log"
print '正在检查并导入项目资源……'
if ! "$ENGINE" --headless --path "$PROJECT_ROOT" --editor --import --quit > "$IMPORT_LOG" 2>&1; then
  print -u2 "资源导入失败，日志：$IMPORT_LOG"
  tail -n 30 "$IMPORT_LOG" >&2
  exit 1
fi
# Godot can report script errors while still returning exit code 0.
if /usr/bin/grep -Eq 'SCRIPT ERROR|Parse Error|^ERROR:' "$IMPORT_LOG"; then
  print -u2 "资源或脚本存在错误，日志：$IMPORT_LOG"
  tail -n 30 "$IMPORT_LOG" >&2
  exit 1
fi
print "启动 Luna-Shot-FPS / $MODE"
if [[ "$MODE" == polar ]]; then
  exec "$ENGINE" --path "$PROJECT_ROOT" --rendering-method forward_plus --resolution 1600x900 "$SCENE" "$@"
fi
if [[ "$MODE" == quarantine || "$MODE" == benchmark ]]; then
  if [[ "$MODE" == quarantine && "${QUARANTINE_COMPAT:-0}" == 1 ]]; then
    exec "$ENGINE" --path "$PROJECT_ROOT" --rendering-method gl_compatibility --resolution 1600x900 "$SCENE" "$@"
  fi
  exec "$ENGINE" --path "$PROJECT_ROOT" --rendering-method forward_plus --resolution 1920x810 "$SCENE" "$@"
fi
# Legacy standalone scenes must retain their original renderer after changing the editor default.
exec "$ENGINE" --path "$PROJECT_ROOT" --rendering-method gl_compatibility "$SCENE" "$@"
