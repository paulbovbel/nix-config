#!/usr/bin/env bash
set -euo pipefail

if (($# > 1)) || (($# == 1)) && [[ "$1" != --dry-run ]]; then
  printf 'Usage: %s [--dry-run]\n' "$0" >&2
  exit 2
fi
dry_run=false
if (($# == 1)); then
  dry_run=true
fi

current_unit=""
pid="$$"
while ((pid > 1)); do
  unit="$(systemctl --user whoami "$pid" 2>/dev/null || true)"
  if [[ "$unit" == app-*.scope ]]; then
    current_unit="$unit"
    break
  fi
  read -r pid < <(ps -o ppid= -p "$pid")
done
if ! $dry_run && [[ -z "$current_unit" ]] && [[ "${XDG_SESSION_TYPE:-}" =~ ^(wayland|x11)$ ]]; then
  printf 'Could not identify the current terminal application; refusing to close graphical applications.\n' >&2
  exit 1
fi

mapfile -t app_units < <(
  while read -r unit _; do
    printf '%s\n' "$unit"
  done < <(
    systemctl --user list-units \
      --type=scope \
      --state=running \
      --no-legend \
      --plain \
      'app-*.scope'
  )
)

closed=0
for unit in "${app_units[@]}"; do
  if [[ "$unit" == "$current_unit" ]]; then
    printf 'Keeping current terminal application: %s\n' "$unit"
    continue
  fi
  if [[ "$unit" == app-gnome-org.gnome.SettingsDaemon.* ]] || [[ "$unit" == app-gnome-org.gnome.Shell* ]]; then
    printf 'Keeping GNOME desktop component: %s\n' "$unit"
    continue
  fi
  if $dry_run; then
    printf 'Would close graphical application: %s\n' "$unit"
  elif systemctl --user stop "$unit"; then
    printf 'Closed graphical application: %s\n' "$unit"
  else
    printf 'Could not close graphical application: %s\n' "$unit" >&2
  fi
  ((closed += 1))
done

if ((closed == 0)); then
  printf 'No other graphical application scopes are running.\n'
fi
