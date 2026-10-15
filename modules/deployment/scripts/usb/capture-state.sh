#!/usr/bin/env bash
set -euo pipefail
if (($# < 2 || $# > 3)); then
  printf 'Usage: %s HOST OUTPUT.age [--close-apps]\n' "$0" >&2
  exit 2
fi
host="$1"
output="$2"
if [[ "$host" != "$(hostname)" ]]; then
  printf 'State capture requires the selected host to match the running hostname.\n' >&2
  exit 1
fi
# shellcheck source=modules/deployment/scripts/source.sh
source "$(dirname "${BASH_SOURCE[0]}")/../source.sh"
recipient="$(<"$repo/secrets/installer/$host-installer-recipient")"
users="$(nix eval --impure --json "$repo#nixosConfigurations.$host.config.rootFs.homeUsers")"
mapfile -t home_users < <(jq -r '.[]' <<<"$users")
if (($# == 3)); then
  [[ "$3" == --close-apps ]]
  "$repo/modules/deployment/scripts/usb/close-graphical-apps.sh"
fi
exec "$repo/modules/deployment/scripts/usb/prepare-state.sh" "$output" "$recipient" "${home_users[@]}"
