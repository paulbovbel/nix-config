#!/usr/bin/env bash
set -euo pipefail

destination="$1"
mkdir -p "$destination"
nix eval --raw .#nixosConfigurations.becmac-pro.config.boot.kernelPackages.kernel.drvPath >"$destination/kernel.drv"
nix eval --raw .#packages.aarch64-linux.attic-client.drvPath >"$destination/attic.drv"

# Transfer the exact evaluated recipes and their source dependencies. The hosted
# runner needs neither private flake inputs nor credentials to evaluate them.
nix-store --query --requisites "$(cat "$destination/kernel.drv")" "$(cat "$destination/attic.drv")" >"$destination/paths"
mapfile -t paths <"$destination/paths"
nix-store --export "${paths[@]}" | zstd -T0 -o "$destination/recipes.nar.zst"
