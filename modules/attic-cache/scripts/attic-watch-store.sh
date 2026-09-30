#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  ATTIC_CACHE
  ATTIC_ENDPOINT
  ATTIC_JOBS
  ATTIC_SERVER_NAME
  ATTIC_TOKEN_FILE
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    printf 'missing required env var: %s\n' "$var" >&2
    exit 1
  fi
done

if [[ ! -s "$ATTIC_TOKEN_FILE" ]]; then
  printf 'Attic token file is missing or empty: %s\n' "$ATTIC_TOKEN_FILE" >&2
  exit 1
fi

while true; do
  if attic login --set-default "$ATTIC_SERVER_NAME" "$ATTIC_ENDPOINT" "$(cat "$ATTIC_TOKEN_FILE")"; then
    attic watch-store -j "$ATTIC_JOBS" "$ATTIC_CACHE" || true
  fi

  printf 'Attic cache is unavailable, retrying in 30 seconds\n' >&2
  sleep 30
done
