#!/usr/bin/env bash
set -euo pipefail
if (($# != 2)); then
  printf 'Usage: %s HOST root@TARGET\n' "$0" >&2
  exit 2
fi
host="$1"
target="$2"
# shellcheck source=modules/deployment/scripts/source.sh
source "$(dirname "${BASH_SOURCE[0]}")/../source.sh"
installer="$(nix eval --impure --raw "$repo#lib.hosts.$host.installer")"
if [[ "$installer" == apple-silicon ]]; then
  printf 'Use the USB installer for Apple Silicon partition reuse and vendor firmware.\n' >&2
  exit 1
fi
ssh "$target" true
temporary_directory="$(mktemp -d)"
trap 'rm -rf -- "$temporary_directory"' EXIT
python3 "$repo/modules/deployment/scripts/usb/prepare-key.py" "$host" extract \
  --output "$temporary_directory/persist/etc/agenix/host.agekey"
# The containing temporary directory stays private on the controller.
chmod 755 "$temporary_directory/persist" "$temporary_directory/persist/etc" "$temporary_directory/persist/etc/agenix"

# Derive caches from the host configuration instead of duplicating their keys.
settings="$(nix eval --impure --json "$repo#nixosConfigurations.$host.config.nix.settings")"
substituters="$(jq -r '.substituters | join(" ")' <<<"$settings")"
trusted_public_keys="$(jq -r '."trusted-public-keys" | join(" ")' <<<"$settings")"
nix build --impure --dry-run "$repo#nixosConfigurations.$host.config.system.build.toplevel"
printf 'Type ERASE %s to install on %s: ' "$host" "$target"
read -r confirmation
[[ "$confirmation" == "ERASE $host" ]]

# This live-environment override disappears on reboot.
{
  printf 'require-sigs = false\nsubstituters = %s\ntrusted-public-keys = %s\n' "$substituters" "$trusted_public_keys"
} | ssh "$target" 'cat > /tmp/nix-deployment.conf
cp --dereference /etc/nix/nix.conf /tmp/nix-deployment-base.conf
cat /tmp/nix-deployment.conf >> /tmp/nix-deployment-base.conf
mount --bind /tmp/nix-deployment-base.conf /etc/nix/nix.conf
systemctl restart nix-daemon'
export NIX_CONFIG="${NIX_CONFIG:-}
substituters = $substituters
trusted-public-keys = $trusted_public_keys"
nixos-anywhere --build-on remote --debug -L --show-trace --option pure-eval false \
  --option substituters "$substituters" \
  --option trusted-public-keys "$trusted_public_keys" \
  --flake "$repo#$host" --phases disko,install,reboot \
  --extra-files "$temporary_directory" "$target"
