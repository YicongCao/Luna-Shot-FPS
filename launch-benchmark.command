#!/bin/zsh
# One-click real-time cinematic benchmark, not a video player.
cd "${0:A:h}"
exec ./tools/launch_game.sh benchmark "$@"
