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

persisted_paths=(
  persist/var/lib/nixos
  persist/etc/machine-id
  persist/etc/NetworkManager/system-connections
  persist/var/lib/NetworkManager
  persist/var/lib/tailscale
  persist/var/lib/bluetooth
  persist/var/lib/cups
  persist/var/lib/flatpak
  persist/var/lib/gdm
)
archive_paths=("${homes[@]}")
for path in "${persisted_paths[@]}"; do
  if [[ -e "/$path" ]]; then
    archive_paths+=("$path")
  else
    printf 'Skipping missing persisted path: /%s\n' "$path" >&2
  fi
done

trap 'status=$?; if ((status != 0)); then rm -f -- "$output"; fi' EXIT

printf 'Archiving home and persisted system state from:\n'
printf '  /%s\n' "${archive_paths[@]}"
printf 'Changed files abort the archive.\n'

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
  "${archive_paths[@]}" |
  zstd --threads=0 --stdout |
  age --recipient "$recipient" --output "$output"

printf 'Prepared encrypted state archive: %s\n' "$output"
