#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  ATTIC_ADMIN_TOKEN_FILE
  ATTIC_CACHE
  ATTIC_ENDPOINT
  ATTIC_SERVER_NAME
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    printf 'missing required env var: %s\n' "$var" >&2
    exit 1
  fi
done

if [[ ! -s "$ATTIC_ADMIN_TOKEN_FILE" ]]; then
  printf 'Attic admin token file is missing or empty: %s\n' "$ATTIC_ADMIN_TOKEN_FILE" >&2
  exit 1
fi

attic login --set-default "$ATTIC_SERVER_NAME" "$ATTIC_ENDPOINT" "$(cat "$ATTIC_ADMIN_TOKEN_FILE")"

if ! attic cache info "$ATTIC_CACHE" >/dev/null; then
  attic cache create --public --priority 41 "$ATTIC_CACHE"
fi
