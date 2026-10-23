#!/usr/bin/env bash
set -euo pipefail

destination="$1"
mkdir -p "$destination"
nix eval --raw .#nixosConfigurations.becmac-pro.config.boot.kernelPackages.kernel.drvPath >"$destination/kernel.drv"
nix-store --query --outputs "$(cat "$destination/kernel.drv")" >"$destination/outputs"
mapfile -t outputs <"$destination/outputs"
if ((${#outputs[@]} > 0)) && nix path-info --store https://nix-cache.bovbel.com/nixos "${outputs[@]}" >/dev/null; then
  printf 'All native kernel outputs are already in Attic; skipping the ARM build.\n'
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf 'cached=true\n' >>"$GITHUB_OUTPUT"; fi
  exit 0
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf 'cached=false\n' >>"$GITHUB_OUTPUT"; fi
nix eval --raw .#packages.aarch64-linux.attic-client.drvPath >"$destination/attic.drv"

# Transfer the exact evaluated recipes and their source dependencies. The hosted
# runner needs neither private flake inputs nor credentials to evaluate them.
nix-store --query --requisites "$(cat "$destination/kernel.drv")" "$(cat "$destination/attic.drv")" >"$destination/paths"
mapfile -t paths <"$destination/paths"
nix-store --export "${paths[@]}" | zstd -T0 -o "$destination/recipes.nar.zst"
