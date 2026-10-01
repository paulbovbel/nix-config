#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
hosts="$(nix eval --raw "$repo#lib.hostNames" --apply 'builtins.concatStringsSep " "')"

# Evaluate separately to keep peak memory bounded as the fleet grows.
for host in $hosts; do
  printf 'Evaluating %s\n' "$host"
  nix eval --json "$repo#lib.hostEvaluations.$host"
done
