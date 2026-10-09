#!/usr/bin/env bash
set -euo pipefail

if (($# < 2)); then
  printf 'Usage: %s <build|build-plan|dry-activate|boot|switch> <host> [--target TARGET] [--build-host BUILDER] [rebuild options...]\n' "$0" >&2
  exit 2
fi

action="$1"
host="$2"
shift 2
# shellcheck source=modules/deployment/scripts/source.sh
source "$(dirname "${BASH_SOURCE[0]}")/../source.sh"
target=""
builder=""
options=()
while (($#)); do
  case "$1" in
  --target | --build-host)
    if (($# < 2)); then
      printf '%s requires a value\n' "$1" >&2
      exit 2
    fi
    if [[ "$1" == --target ]]; then target="$2"; else builder="$2"; fi
    shift 2
    ;;
  *)
    options+=("$1")
    shift
    ;;
  esac
done
case "$action" in
build | build-plan)
  if [[ -n "$target" || -n "$builder" ]]; then
    printf '%s builds on the controller; target and builder overrides apply to activation commands.\n' "$action" >&2
    exit 2
  fi
  build_options=(--out-link "$repo/result-$host" -L)
  if [[ "$action" == build-plan ]]; then build_options+=(--dry-run); fi
  exec nix build --impure "$repo#nixosConfigurations.$host.config.system.build.toplevel" "${build_options[@]}" "${options[@]}"
  ;;
boot | switch | dry-activate) ;;
*)
  printf 'Unknown deployment action: %s\n' "$action" >&2
  exit 2
  ;;
esac

configured_host="$(nix eval --impure --raw "$repo#nixosConfigurations.$host.config.networking.hostName")"
[[ "$configured_host" == "$host" ]]

if [[ -z "$target" && "$host" == "$(hostname)" ]]; then
  if [[ -n "$builder" && "$builder" != localhost ]]; then options+=(--build-host "$builder"); fi
  exec sudo --preserve-env=SSH_AUTH_SOCK,NIX_CONFIG_BRANCH,NIX_CONFIG_REVISION \
    nixos-rebuild "$action" --impure --flake "$repo#$host" -L "${options[@]}"
fi

target="${target:-$host}"
builder="${builder:-$target}"
if [[ "$builder" == localhost ]]; then builder=""; fi
if [[ -n "$builder" ]]; then options+=(--build-host "$builder"); fi

exec nixos-rebuild "$action" --impure --show-trace --flake "$repo#$host" \
  --target-host "$target" --sudo --ask-sudo-password -L "${options[@]}"
