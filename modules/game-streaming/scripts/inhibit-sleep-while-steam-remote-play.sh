#!/usr/bin/env bash
set -euo pipefail

active_remote_play() {
  local steam_pid steam_started log
  steam_pid=$(pgrep -u "$UID" -o -x steam) || return 1
  steam_started=$(LC_ALL=C ps -p "$steam_pid" -o lstart=) || return 1
  [[ -n "$steam_started" ]] || return 1
  steam_started=$(LC_ALL=C date -d "$steam_started" '+%Y-%m-%d %H:%M:%S') || return 1

  for log in "${XDG_DATA_HOME:-$HOME/.local/share}/Steam/logs/streaming_log.txt" \
    "$HOME/.steam/steam/logs/streaming_log.txt"; do
    [[ -r "$log" ]] || continue
    # Ignore previous Steam runs, including sessions interrupted by a crash.
    # Game Recording shares this log; only Remote Play events change our state.
    awk -v started="$steam_started" '
      substr($0, 2, 19) >= started {
        if ($0 ~ /Streaming started to /) active = 1
        if ($0 ~ /Stopped desktop stream|Streaming stopped|Client version:/) active = 0
      }
      END { exit !active }
    ' "$log"
    return "$?"
  done
  return 1
}

if [[ "${1:-}" == "--wait" ]]; then
  while active_remote_play; do
    sleep 5
  done
  exit 0
fi

while true; do
  if active_remote_play; then
    systemd-inhibit --what=idle:sleep --mode=block \
      --who="Steam Remote Play" --why="Active Steam Remote Play session" \
      "$0" --wait
  else
    sleep 5
  fi
done
