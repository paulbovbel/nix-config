#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  printf 'usage: %s <user> <group> <container> <iface> <mam_id_env_var>\n' "$0" >&2
  exit 2
fi

media_user="$1"
container="$3"
iface="$4"
mam_id_var="$5"

if [[ -z "${!mam_id_var:-}" ]]; then
  printf 'missing required env var: %s\n' "$mam_id_var" >&2
  exit 1
fi

media_uid="$(id -u "$media_user")"
media_gid="$(id -g "$media_user")"
mam_id="${!mam_id_var}"

podman exec -iu "${media_uid}:${media_gid}" \
  -e CONTAINER_INTERFACE="$iface" \
  -e MAM_ID="$mam_id" \
  "$container" /bin/bash <<'EOF'
set -euo pipefail

mam_api="https://t.myanonamouse.net/json/dynamicSeedbox.php"
config_dir="/config"
cached_ip="$config_dir/mam.ip.$CONTAINER_INTERFACE"
cookie_jar="$config_dir/mam.cookies.$CONTAINER_INTERFACE"

get_ip() {
  curl --interface "$CONTAINER_INTERFACE" -s checkip.amazonaws.com
}

touch "$cached_ip"
new_ip="$(get_ip)"
old_ip="$(cat "$cached_ip")"

if [[ "$new_ip" == "$old_ip" ]]; then
  printf 'MAM IP unchanged for %s: %s\n' "$CONTAINER_INTERFACE" "$new_ip"
  exit 0
fi

if [[ -f "$cookie_jar" ]]; then
  curl -w "\n" --interface "$CONTAINER_INTERFACE" --fail-with-body -b "$cookie_jar" -c "$cookie_jar" "$mam_api"
else
  curl -w "\n" --interface "$CONTAINER_INTERFACE" --fail-with-body -b "mam_id=$MAM_ID" -c "$cookie_jar" "$mam_api"
fi

printf '%s\n' "$new_ip" >"$cached_ip"
printf 'Updated MAM IP for %s: %s -> %s\n' "$CONTAINER_INTERFACE" "$old_ip" "$new_ip"
EOF
