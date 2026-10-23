#!/usr/bin/env bash
set -euo pipefail

source_directory="$1"
zstd --decompress --stdout "$source_directory/recipes.nar.zst" | nix-store --import >/dev/null
attic_drv="$(cat "$source_directory/attic.drv")"
kernel_drv="$(cat "$source_directory/kernel.drv")"
attic="$(nix build --no-link --print-out-paths "$attic_drv^out")/bin/attic"
nix build -L --json --out-link "$source_directory/result-kernel" "$kernel_drv^*" >"$source_directory/kernel.json"
mapfile -t outputs < <(jq -r '.[].outputs[]' "$source_directory/kernel.json")
"$attic" login bovbel https://nix-cache.bovbel.com "$ATTIC_TOKEN"
"$attic" push bovbel:nixos "${outputs[@]}"
