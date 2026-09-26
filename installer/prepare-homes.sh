#!/usr/bin/env bash
set -euo pipefail

if (($# < 3)); then
  printf 'Usage: %s <output.tar.zst.age> <recipient> <user>...\n' "$0" >&2
  exit 2
fi

output="$1"
recipient="$2"
shift 2
homes=()
for user in "$@"; do
  if [[ -d "/home/$user" ]]; then
    homes+=("home/$user")
  else
    printf 'Skipping missing home directory: /home/%s\n' "$user" >&2
  fi
done
if ((${#homes[@]} == 0)); then
  printf 'No configured home directories exist to archive.\n' >&2
  exit 1
fi

trap 'status=$?; if ((status != 0)); then rm -f -- "$output"; fi' EXIT

printf 'Archiving application state from:\n'
printf '  /%s\n' "${homes[@]}"
printf 'Close applications that may write to these directories. Changed files abort the archive.\n'

sudo tar \
  --create \
  --directory=/ \
  --acls \
  --xattrs \
  --numeric-owner \
  --sparse \
  --one-file-system \
  --exclude='home/*/Desktop' \
  --exclude='home/*/Documents' \
  --exclude='home/*/Downloads' \
  --exclude='home/*/Music' \
  --exclude='home/*/Pictures' \
  --exclude='home/*/Public' \
  --exclude='home/*/Templates' \
  --exclude='home/*/Videos' \
  --exclude='home/*/.cache' \
  --exclude='home/*/.local/share/Trash' \
  --exclude='home/*/.var/app/*/cache' \
  "${homes[@]}" |
  zstd --threads=0 --stdout |
  age --recipient "$recipient" --output "$output"

printf 'Prepared encrypted home archive: %s\n' "$output"
