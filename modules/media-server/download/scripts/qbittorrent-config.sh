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
crudini --set "$config_file" Preferences 'WebUI\LocalHostAuth' false
# Start fail-closed until the port reconciler observes an active PIA forward.
crudini --set "$config_file" BitTorrent 'Session\Interface' lo
crudini --set "$config_file" BitTorrent 'Session\InterfaceName' lo
crudini --set "$config_file" BitTorrent 'Session\InterfaceAddress' ''
crudini --set "$config_file" Preferences 'Connection\UPnP' false
# Pre-5.x key names, kept until a running instance confirms they are ignored.
crudini --set "$config_file" Preferences 'Connection\Interface' lo
crudini --set "$config_file" Preferences 'Connection\InterfaceName' lo
