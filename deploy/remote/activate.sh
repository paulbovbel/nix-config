#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
  printf 'Usage: %s <boot|switch> <host>\n' "$0" >&2
  exit 2
fi

action="$1"
host="$2"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
configuration_branch="$(git -C "$repo" branch --show-current)"
if [[ -z "$configuration_branch" ]]; then
  printf 'Cannot activate from a detached HEAD; check out the intended branch first.\n' >&2
  exit 1
fi

# Auto-upgrade needs this repository's branch, so activation must be impure.
export NIX_CONFIG_BRANCH="$configuration_branch"

configured_host="$(nix eval --impure --raw "$repo#nixosConfigurations.$host.config.networking.hostName")"
[[ "$configured_host" == "$host" ]]

if [[ "$host" == "$(hostname)" ]]; then
  exec sudo --preserve-env=SSH_AUTH_SOCK,NIX_CONFIG_BRANCH \
    nixos-rebuild "$action" --impure --flake "$repo#$host" -L
fi

target_system="$(nix eval --impure --raw "$repo#nixosConfigurations.$host.config.nixpkgs.hostPlatform.system")"
if [[ "$target_system" == aarch64-* ]]; then
  printf 'Remote deployment of aarch64 hosts is not supported: %s\n' "$host" >&2
  exit 1
fi

exec nixos-rebuild "$action" --impure --flake "$repo#$host" \
  --target-host "$host" --build-host "$host" --sudo --ask-sudo-password -L
