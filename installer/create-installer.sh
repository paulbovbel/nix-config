#!/usr/bin/env bash
set -euo pipefail

: "${HOST_NAMES:?configured host names are missing}"

if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "Usage: nix run .#create-installer -- <host> /dev/<usb-device> [host-key-source] [installer-iso]" >&2
  exit 1
fi

host_name=$1
usb_device=$2
host_key_source=${3:-}
installer_iso=${4:-}

if [[ -n $installer_iso && -z $host_key_source ]]; then
  echo "Reusing an installer ISO requires its matching host key." >&2
  exit 1
fi

if [[ " $HOST_NAMES " != *" $host_name "* ]]; then
  echo "Unknown host '$host_name'. Expected one of: $HOST_NAMES" >&2
  exit 1
fi

if [[ ! -f flake.nix || ! -f secrets.nix ]]; then
  echo "Run this command from the repository root." >&2
  exit 1
fi

if [[ ! -b $usb_device || $(lsblk --noheadings --nodeps --raw --output TYPE "$usb_device") != disk ]]; then
  echo "Not a whole-disk block device: $usb_device" >&2
  exit 1
fi

if ! sudo -v; then
  echo "Could not obtain privileged access to $usb_device." >&2
  exit 1
fi

if ! usb_size=$(sudo "$(command -v blockdev)" --getsize64 "$usb_device") || [[ $usb_size -eq 0 ]]; then
  echo "No accessible storage medium found at $usb_device." >&2
  exit 1
fi

if [[ $(sudo "$(command -v blockdev)" --getro "$usb_device") -ne 0 ]]; then
  echo "USB device is read-only: $usb_device" >&2
  exit 1
fi

while read -r path; do
  if findmnt --noheadings --source "$path" >/dev/null; then
    echo "Unmounting filesystems on $path"
    sudo "$(command -v umount)" --all-targets "$path"
  fi
done < <(lsblk --noheadings --raw --paths --output NAME "$usb_device" | tac)

while read -r path; do
  if findmnt --noheadings --source "$path" >/dev/null; then
    echo "Could not unmount all filesystems on $path." >&2
    exit 1
  fi
done < <(lsblk --noheadings --raw --paths --output NAME "$usb_device")

echo "This will replace the $host_name age identity, re-encrypt its secrets,"
echo "and erase all data on $usb_device:"
lsblk --output NAME,SIZE,TYPE,MODEL,SERIAL "$usb_device"
read -r -p "Type '$host_name' to continue: " confirmation
if [[ $confirmation != "$host_name" ]]; then
  echo "Installer creation cancelled."
  exit 1
fi

tmpdir=$(mktemp -d)
host_key="$tmpdir/host.agekey"
key_mount="$tmpdir/key-mount"
completed=false

cleanup() {
  if mountpoint --quiet "$key_mount"; then
    sudo "$(command -v umount)" "$key_mount"
  fi
  if [[ $completed == true ]]; then
    rm -rf "$tmpdir"
  else
    echo "Installer creation failed; the new host key is retained at $host_key" >&2
  fi
}
trap cleanup EXIT

if [[ -z $host_key_source ]]; then
  age-keygen -o "$host_key"
elif [[ $host_key_source == *:* ]]; then
  scp -- "$host_key_source" "$host_key"
  chmod 0600 "$host_key"
else
  install --mode=0600 "$host_key_source" "$host_key"
fi

host_recipient=$(age-keygen -y "$host_key")
host_key_name=${host_name//-/_}
current_recipient=$(sed -n -E "s|^  ${host_key_name} = \"([^\"]*)\";|\1|p" secrets.nix)

if [[ -z $current_recipient ]]; then
  echo "Could not find the $host_key_name recipient in secrets.nix." >&2
  exit 1
fi

if [[ $current_recipient != "$host_recipient" ]]; then
  sed -i -E "s|^  ${host_key_name} = \"[^\"]*\";|  ${host_key_name} = \"${host_recipient}\";|" secrets.nix
  agenix -r
else
  echo "The supplied key already matches secrets.nix; keeping the existing encrypted secrets."
fi

if [[ -n $installer_iso ]]; then
  iso_files=("$installer_iso")
else
  nix build ".#installer-${host_name}" --out-link "$tmpdir/result"
  iso_files=("$tmpdir"/result/iso/*.iso)
fi

if [[ ${#iso_files[@]} -ne 1 || ! -f ${iso_files[0]} ]]; then
  echo "Expected exactly one installer ISO." >&2
  exit 1
fi

sudo "$(command -v dd)" if="${iso_files[0]}" of="$usb_device" bs=4M status=progress conv=fsync
sudo "$(command -v partx)" --update "$usb_device"

declare -A existing_partitions=()
while read -r path type; do
  if [[ $type == part ]]; then
    existing_partitions["$path"]=1
  fi
done < <(lsblk --noheadings --raw --paths --output NAME,TYPE "$usb_device")

printf ',,c\n' | sudo "$(command -v sfdisk)" --append "$usb_device"
sudo "$(command -v partx)" --update "$usb_device"

key_partition=
for _ in {1..10}; do
  while read -r path type; do
    if [[ $type == part && -z ${existing_partitions[$path]+present} ]]; then
      key_partition=$path
    fi
  done < <(lsblk --noheadings --raw --paths --output NAME,TYPE "$usb_device")
  [[ -n $key_partition ]] && break
  sleep 1
done

if [[ -z $key_partition ]]; then
  echo "Could not find the new NIXOS_KEYS partition." >&2
  exit 1
fi

sudo "$(command -v mkfs.vfat)" -F 32 -n NIXOS_KEYS "$key_partition"
mkdir "$key_mount"
sudo "$(command -v mount)" "$key_partition" "$key_mount"
sudo "$(command -v install)" --mode=0600 "$host_key" "$key_mount/host.agekey"
sync
sudo "$(command -v umount)" "$key_mount"

completed=true
echo "Created the $host_name installer on $usb_device."
echo "Review and commit the rekeyed secrets before installing the host."
