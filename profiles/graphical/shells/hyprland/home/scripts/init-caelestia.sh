#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"

if [ ! -f "$state_dir/scheme.json" ]; then
  caelestia scheme set -n caelestia
fi

if [ ! -f "$state_dir/wallpaper/path.txt" ]; then
  caelestia wallpaper -f "$1"
fi
