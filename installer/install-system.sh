#!/usr/bin/env bash
set -euo pipefail

: "${HOST_NAME:?installer host name is missing}"
: "${TARGET_DISK:?installer target disk is missing}"
: "${DISKO_SCRIPT:?installer disko script is missing}"
: "${NIXOS_INSTALL:?nixos-install path is missing}"
: "${TARGET_SYSTEM:?target system closure is missing}"

if [[ $EUID -ne 0 ]]; then
  echo "Run this command as root." >&2
  exit 1
fi

if [[ $# -gt 1 ]]; then
  echo "Usage: install-system [/path/to/host.agekey]" >&2
  exit 1
fi

key_mount=/run/installer-key
mounted_key=false
cleanup() {
  if [[ $mounted_key == true ]]; then
    umount "$key_mount"
  fi
}
trap cleanup EXIT

if [[ $# -eq 1 ]]; then
  host_key=$1
else
  mkdir -p "$key_mount"
  mount -o ro /dev/disk/by-label/NIXOS_KEYS "$key_mount"
  mounted_key=true
  host_key="$key_mount/host.agekey"
fi

if [[ ! -f $host_key ]]; then
  echo "Host age key not found: $host_key" >&2
  exit 1
fi

if [[ ! -b $TARGET_DISK ]]; then
  echo "Configured target disk is not present: $TARGET_DISK" >&2
  exit 1
fi

echo "This will install $HOST_NAME and erase all data on:"
lsblk --output NAME,SIZE,TYPE,MODEL,SERIAL "$TARGET_DISK"
read -r -p "Type '$HOST_NAME' to continue: " confirmation
if [[ $confirmation != "$HOST_NAME" ]]; then
  echo "Installation cancelled."
  exit 1
fi

"$DISKO_SCRIPT"
install -D --mode=0600 "$host_key" /mnt/persist/etc/agenix/host.agekey
"$NIXOS_INSTALL" --root /mnt --system "$TARGET_SYSTEM" --no-root-password
sync

echo "Installation complete. Remove the installer media and reboot."
