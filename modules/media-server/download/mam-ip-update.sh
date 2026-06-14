#!/usr/bin/env bash
set -euo pipefail

media_user="$1"
media_group="$2"

media_uid="$(id -u "$media_user")"
media_gid="$(getent group "$media_group" | cut -d: -f3)"

update_mam() {
  local container="$1"
  local iface="$2"
  local mam_id="$3"

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

if [[ "$new_ip" != "$old_ip" ]]; then
  if [[ -f "$cookie_jar" ]]; then
    curl -w "\n" --interface "$CONTAINER_INTERFACE" --fail-with-body -b "$cookie_jar" -c "$cookie_jar" "$mam_api"
  else
    curl -w "\n" --interface "$CONTAINER_INTERFACE" --fail-with-body -b "mam_id=$MAM_ID" -c "$cookie_jar" "$mam_api"
  fi
  printf '%s\n' "$new_ip" >"$cached_ip"
fi
EOF
}

update_mam deluge wg0 "$MAM_ID_DELUGE"
update_mam jackett eth0 "$MAM_ID_JACKETT"
