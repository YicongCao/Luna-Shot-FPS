#!/bin/zsh
set -eu
ROOT="${0:A:h:h:h}"
ENGINE="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
TMP="$(mktemp -d /tmp/luna-quarantine-movie.XXXXXX)"
# MovieWriter initializes before command-line window resizing. An isolated config
# keeps the movie framebuffer and logical viewport equal without changing baseline.
python3 -I - "$ROOT" "$TMP" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
text=(root/'project.godot').read_text()
for old,new in [('viewport_width=1440','viewport_width=1920'),('viewport_height=900','viewport_height=810'),('window_width_override=1280','window_width_override=1920'),('window_height_override=800','window_height_override=810')]:
    text=text.replace(old,new)
(out/'project.godot').write_text(text)
for name in ['assets','scripts','scenes','docs','tools','.godot']:
    (out/name).symlink_to(root/name, target_is_directory=True)
PY
OUT="${QUARANTINE_MOVIE_OUTPUT:-$ROOT/docs/validation/quarantine-v1}"
mkdir -p "$ROOT/artifacts/quarantine/movie"
MOVIE_DIR="$(mktemp -d "$ROOT/artifacts/quarantine/movie/refine.XXXXXX")"
mkdir -p "$OUT"
"$ENGINE" --path "$TMP" --rendering-method forward_plus --resolution 1920x810 --write-movie "$MOVIE_DIR/wide.avi" --fixed-fps 60 --script res://tools/quarantine/showcase.gd -- --quarantine-qa > "$OUT/showcase.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|^ERROR:' "$OUT/showcase.log"; then exit 1; fi
ffmpeg -hide_banner -loglevel warning -y -i "$MOVIE_DIR/wide.avi" -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart "$OUT/showcase.mp4"
print "Native reel saved; temporary configuration: $TMP"
