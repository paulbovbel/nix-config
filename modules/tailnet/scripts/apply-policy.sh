#!/usr/bin/env bash
set -euo pipefail

policy="${1:?Usage: apply-policy.sh POLICY.json}"
: "${TAILSCALE_OAUTH_CLIENT_ID:?Missing OAuth client ID}"
: "${TAILSCALE_OAUTH_CLIENT_SECRET:?Missing OAuth client secret}"

# Send credentials on stdin rather than exposing them in process arguments.
token=$(jq -nj '
  "client_id=\(env.TAILSCALE_OAUTH_CLIENT_ID | @uri)&client_secret=\(env.TAILSCALE_OAUTH_CLIENT_SECRET | @uri)"
' | curl --fail --silent --show-error --max-time 30 \
  --data-binary @- https://api.tailscale.com/api/v2/oauth/token |
  jq -er '.access_token | select(type == "string" and length > 0)')
unset TAILSCALE_OAUTH_CLIENT_ID TAILSCALE_OAUTH_CLIENT_SECRET

api() {
  printf 'Authorization: Bearer %s\n' "$token" |
    curl --fail-with-body --silent --show-error --max-time 30 \
      --header @- --header 'Content-Type: application/json' \
      --data-binary "@$policy" "https://api.tailscale.com/api/v2/tailnet/-/acl$1"
}

if ! api /validate | jq -e 'if . == {} then true else error(tojson) end' >/dev/null; then
  printf 'Tailscale policy validation failed\n' >&2
  exit 1
fi
printf 'Tailscale policy validation passed\n'
api '' >/dev/null
printf 'Applied generated Tailscale policy\n'
