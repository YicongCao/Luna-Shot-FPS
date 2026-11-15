#!/bin/zsh
export LS01_BASELINE=1
exec "${0:A:h}/tools/launch_game.sh" lab "$@"
