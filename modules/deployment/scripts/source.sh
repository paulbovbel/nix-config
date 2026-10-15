#!/usr/bin/env bash
# Shared source metadata for deployment entry points. Source this file.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export NIX_CONFIG_BRANCH
NIX_CONFIG_BRANCH="$(git -C "$repo" branch --show-current)"
if [[ -z "$NIX_CONFIG_BRANCH" ]]; then
  printf 'Check out the intended branch before deploying.\n' >&2
  exit 1
fi
export NIX_CONFIG_REVISION
NIX_CONFIG_REVISION="$(git -C "$repo" rev-parse HEAD)"
if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
  NIX_CONFIG_REVISION+="-dirty"
fi
