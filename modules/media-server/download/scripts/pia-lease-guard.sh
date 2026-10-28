#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <server-name-file> <gluetun-dir>" >&2
  exit 2
fi

server_name_file=$1
gluetun_dir=$2
marker="$gluetun_dir/.registered-server"

# PIA issues the forwarding lease for one specific server. Re-registration can
# land on a different server, and Gluetun replays the stored lease and is told
# "bad signature", so discard the lease exactly when the server changes and
# keep it otherwise, since the port is stable for 60 days.
if [ -f "$marker" ] && cmp -s "$server_name_file" "$marker"; then
  exit 0
fi

rm -f "$gluetun_dir/piaportforward.json"
install -m 0600 "$server_name_file" "$marker"
