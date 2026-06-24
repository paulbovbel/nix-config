#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  printf 'usage: %s <user> <container> <iface> <mam_id_env_var> <container_script>\n' "$0" >&2
  exit 2
fi

# Resolve the host-side inputs before entering the container. The secret is
# passed in by env var name so the same script can serve multiple MAM sessions.
media_user="$1"
container="$2"
iface="$3"
mam_id_var="$4"
container_script="$5"

if [[ -z "${!mam_id_var:-}" ]]; then
  printf 'missing required env var: %s\n' "$mam_id_var" >&2
  exit 1
fi

media_uid="$(id -u "$media_user")"
media_gid="$(id -g "$media_user")"
mam_id="${!mam_id_var}"

# Run the updater inside the target app container so curl can use the same
# network namespace and interface name as the service MAM will see traffic from.
podman exec -iu "${media_uid}:${media_gid}" \
  -e CONTAINER_INTERFACE="$iface" \
  -e MAM_ID="$mam_id" \
  "$container" /bin/bash <"$container_script"
