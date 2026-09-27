#!/usr/bin/env bash
set -euo pipefail

if (($# < 1 || $# > 2)); then
  printf 'Usage: %s <installer.iso> [/dev/disk/by-id/usb-...]\n' "$0" >&2
  exit 2
fi

image="$1"
device="${2:-}"

if [[ ! -f "$image" ]]; then
  printf 'Installer image does not exist: %s\n' "$image" >&2
  exit 1
fi

if [[ -z "$device" ]]; then
  shopt -s nullglob
  declare -A seen_devices=()
  devices=()
  for candidate in /dev/disk/by-id/usb-*; do
    if [[ ! -b "$candidate" ]] || [[ "$(lsblk -dnro TYPE "$candidate")" != disk ]]; then
      continue
    fi
    real_device="$(readlink -f "$candidate")"
    if [[ -n "${seen_devices[$real_device]:-}" ]]; then
      continue
    fi
    seen_devices[$real_device]=1
    devices+=("$candidate")
  done

  if ((${#devices[@]} == 0)); then
    printf 'No whole USB disks were found under /dev/disk/by-id.\n' >&2
    exit 1
  fi

  printf 'Available USB disks:\n'
  for index in "${!devices[@]}"; do
    printf '  [%d] %s\n' "$((index + 1))" "${devices[$index]}"
    while read -r details; do
      printf '      %s\n' "$details"
    done < <(lsblk -dno SIZE,MODEL,TRAN,MOUNTPOINTS "${devices[$index]}")
  done
  printf 'Select a USB disk [1-%d]: ' "${#devices[@]}"
  read -r selection
  if [[ ! "$selection" =~ ^[0-9]+$ ]] || ((selection < 1 || selection > ${#devices[@]})); then
    printf 'Invalid USB disk selection.\n' >&2
    exit 1
  fi
  device="${devices[$((selection - 1))]}"
fi

if [[ "$device" != /dev/disk/by-id/usb-* ]] || [[ ! -b "$device" ]]; then
  printf 'Refusing device that is not a USB by-id block device: %s\n' "$device" >&2
  exit 1
fi
if [[ "$(lsblk -dnro TYPE "$device")" != disk ]]; then
  printf 'Refusing device that is not a whole disk: %s\n' "$device" >&2
  exit 1
fi

root_source="$(findmnt -nro SOURCE /)"
root_block_sources=()
if [[ "$root_source" == /dev/* ]]; then
  root_block_sources+=("$root_source")
elif [[ "$(findmnt -nro FSTYPE /)" == zfs ]] && command -v zpool >/dev/null; then
  root_pool="${root_source%%/*}"
  while read -r path _; do
    if [[ "$path" == /dev/* ]]; then
      root_block_sources+=("$path")
    fi
  done < <(zpool status -LP "$root_pool")
fi
if ((${#root_block_sources[@]} == 0)); then
  printf 'Could not identify the block device backing the current root filesystem; refusing to write.\n' >&2
  exit 1
fi

device_real="$(readlink -f "$device")"
for root_block_source in "${root_block_sources[@]}"; do
  while read -r root_device; do
    if [[ "$device_real" == "$(readlink -f "$root_device")" ]]; then
      printf 'Refusing USB device that backs the current root filesystem: %s\n' "$device" >&2
      exit 1
    fi
  done < <(lsblk -s -nrpo NAME "$root_block_source")
done

mountpoints="$(lsblk -nrpo MOUNTPOINTS "$device")"
if [[ "$mountpoints" =~ [^[:space:]] ]]; then
  printf 'Refusing mounted or active-swap USB device: %s\n' "$device" >&2
  exit 1
fi

lsblk -o NAME,PATH,SIZE,MODEL,TRAN,MOUNTPOINTS "$device"
printf '\nType WRITE to erase this USB device: '
read -r confirmation
if [[ "$confirmation" != WRITE ]]; then
  printf 'USB write cancelled.\n'
  exit 1
fi

pid_directory="$(mktemp -d --tmpdir write-usb-dd.XXXXXXXX)"
pid_file="$pid_directory/pid"
cleanup_pid_file() {
  rm -rf -- "$pid_directory"
}
trap cleanup_pid_file EXIT

sudo -v
sudo -n bash -c '
  set -e
  printf "%s\n" "$BASHPID" >"$1"
  exec dd if="$2" of="$3" bs=4M conv=fsync status=progress
' _ "$pid_file" "$image" "$device" &
sudo_pid=$!

cancel_write() {
  trap - INT TERM
  if [[ -s "$pid_file" ]]; then
    dd_pid="$(<"$pid_file")"
    sudo -n kill -INT "$dd_pid" 2>/dev/null || true
  else
    sudo -n kill -INT "$sudo_pid" 2>/dev/null || true
  fi
  wait "$sudo_pid" 2>/dev/null || true
  printf '\nUSB write cancelled.\n' >&2
  exit 130
}
trap cancel_write INT TERM

write_status=0
wait "$sudo_pid" || write_status=$?
trap - INT TERM
if ((write_status != 0)); then
  printf 'USB write failed with status %d.\n' "$write_status" >&2
  exit "$write_status"
fi

printf 'Wrote %s to %s\n' "$image" "$device"
