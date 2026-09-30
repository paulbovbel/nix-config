#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <config-file> <uid> <gid>" >&2
  exit 2
fi

config_file=$1
uid=$2
gid=$3

podman_apps_network=$(podman network inspect apps --format '{{json .Subnets}}' | jq -r 'map(.subnet) | join(",")')
if [ -z "$podman_apps_network" ]; then
  echo "No subnet found for Podman network apps" >&2
  exit 1
fi

install -d -m 0755 -o "$uid" -g "$gid" "$(dirname "$config_file")"
touch "$config_file"
chown "$uid:$gid" "$config_file"

crudini --set "$config_file" Preferences 'WebUI\AuthSubnetWhitelistEnabled' true
crudini --set "$config_file" Preferences 'WebUI\AuthSubnetWhitelist' "$podman_apps_network"
crudini --set "$config_file" Preferences 'WebUI\ReverseProxySupportEnabled' true
