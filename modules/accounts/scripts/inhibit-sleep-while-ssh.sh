#!/usr/bin/env bash
set -euo pipefail

active_ssh() {
  pgrep -x sshd >/dev/null && who | grep -q " pts/"
}

while true; do
  if active_ssh; then
    systemd-inhibit --what=sleep --why="Active SSH session" bash -lc '
      active_ssh() {
        pgrep -x sshd >/dev/null && who | grep -q " pts/"
      }
      while active_ssh; do
        sleep 10
      done
    '
  else
    sleep 10
  fi
done
