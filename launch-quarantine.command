#!/bin/zsh
cd "${0:A:h}"
exec ./tools/launch_game.sh quarantine "$@"
