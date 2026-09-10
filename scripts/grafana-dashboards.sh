#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
secret_file="secrets/management/grafana-cloud-env.age"

cd "$repo_root"

if [[ ! -f $secret_file ]]; then
  printf 'Missing Grafana management credentials: %s/%s\n' "$repo_root" "$secret_file" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source <(agenix -d "$secret_file")
set +a

: "${GRAFANA_TOKEN:?GRAFANA_TOKEN is missing from $secret_file}"
export GRAFANA_SERVER="https://bovbel.grafana.net"

exec gcx resources push --path "$repo_root/monitoring/grafana" --on-error abort "$@"
