#!/usr/bin/env bash
set -euo pipefail

active_stream() {
  local invocation
  systemctl --user is-active --quiet sunshine.service || return 1
  invocation=$(systemctl --user show sunshine.service --property=InvocationID --value) || return 1
  [[ -n "$invocation" ]] || return 1
  # Limit events to the current Sunshine run so crashes/restarts cannot leave
  # stale clients. Count clients so one disconnect does not release other streams.
  journalctl --user --unit=sunshine.service --invocation="$invocation" \
    --output=cat --no-pager |
    awk '
      /CLIENT CONNECTED/ { clients++ }
      /CLIENT DISCONNECTED/ { if (clients > 0) clients-- }
      END { exit !(clients > 0) }
    '
}

if [[ "${1:-}" == "--wait" ]]; then
  while active_stream; do
    sleep 5
  done
  exit 0
fi

while true; do
  if active_stream; then
    systemd-inhibit --what=idle:sleep --mode=block \
      --who="Sunshine" --why="Active Sunshine streaming session" \
      "$0" --wait
  else
    sleep 5
  fi
done
