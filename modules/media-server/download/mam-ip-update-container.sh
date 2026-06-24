#!/usr/bin/env bash
set -euo pipefail
umask 077

mam_api="https://t.myanonamouse.net/json/dynamicSeedbox.php"
config_dir="/config"
cached_ip="$config_dir/mam.ip.$CONTAINER_INTERFACE"
cookie_jar="$config_dir/mam.cookies.$CONTAINER_INTERFACE"
cookie_fingerprint="$config_dir/mam.cookie-fingerprint.$CONTAINER_INTERFACE"

# Ask an external service which public IP this container interface exits from.
get_ip() {
  curl --interface "$CONTAINER_INTERFACE" --fail --silent --show-error --max-time 10 \
    https://checkip.amazonaws.com
}

# Call MAM through the selected interface, using either an existing cookie jar
# or the secret mam_id cookie supplied by the caller.
call_mam_api() {
  curl --interface "$CONTAINER_INTERFACE" --fail-with-body --silent --show-error --max-time 30 \
    -w "\n" "$@" "$mam_api"
}

# HTTP success is not always application success, so reject explicit MAM failure
# responses before updating local state.
validate_mam_response() {
  local response="$1"
  local success_false_regex='"[Ss]uccess"[[:space:]]*:[[:space:]]*false'

  if [[ "$response" =~ $success_false_regex ]]; then
    printf 'MAM API rejected update for %s: %s\n' "$CONTAINER_INTERFACE" "$response" >&2
    return 1
  fi
}

# Track a hash of the current mam_id. If the secret changes, discard the old
# cookie and cached IP so the next request authenticates with the new secret.
new_fingerprint="$(printf '%s' "$MAM_ID" | sha256sum)"
new_fingerprint="${new_fingerprint%% *}"
old_fingerprint=""
if [[ -f "$cookie_fingerprint" ]]; then
  old_fingerprint="$(cat "$cookie_fingerprint")"
fi

if [[ "$new_fingerprint" != "$old_fingerprint" ]]; then
  rm -f "$cached_ip" "$cookie_jar"
fi

# Stop early if the IP check fails or returns something that does not look like
# an IPv4/IPv6 address; this prevents poisoning the cache with error pages.
new_ip="$(get_ip)"
if [[ ! "$new_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && ! "$new_ip" =~ ^[0-9A-Fa-f:]+$ ]]; then
  printf 'invalid IP from check service for %s: %s\n' "$CONTAINER_INTERFACE" "$new_ip" >&2
  exit 1
fi

# Compare against the last successfully registered IP. An unchanged IP can skip
# the MAM API entirely, preserving rate limits and avoiding needless auth churn.
old_ip=""
if [[ -f "$cached_ip" ]]; then
  old_ip="$(<"$cached_ip")"
fi

if [[ "$new_ip" == "$old_ip" ]]; then
  printf 'MAM IP unchanged for %s: %s\n' "$CONTAINER_INTERFACE" "$new_ip"
  exit 0
fi

# Reuse the cookie jar when possible; otherwise bootstrap it from the secret
# mam_id cookie. Curl failures include the response body in stderr for debugging.
if [[ -f "$cookie_jar" ]]; then
  if ! response="$(call_mam_api -b "$cookie_jar" -c "$cookie_jar")"; then
    printf '%s\n' "$response" >&2
    exit 1
  fi
else
  if ! response="$(call_mam_api -b "mam_id=$MAM_ID" -c "$cookie_jar")"; then
    printf '%s\n' "$response" >&2
    exit 1
  fi
fi
validate_mam_response "$response"
printf '%s\n' "$response"

# Only persist local state after MAM accepts the update. This keeps retries
# correct after network/API/auth failures.
printf '%s\n' "$new_ip" >"$cached_ip"
printf '%s\n' "$new_fingerprint" >"$cookie_fingerprint"
printf 'Updated MAM IP for %s: %s -> %s\n' "$CONTAINER_INTERFACE" "$old_ip" "$new_ip"
