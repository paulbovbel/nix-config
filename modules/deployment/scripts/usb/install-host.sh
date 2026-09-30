#!/usr/bin/env bash
set -euo pipefail

# Supplied by the host-specific Nix wrapper.
: "${host_name:?}" "${erase_description:?}" "${expected_recipient:?}"
: "${unlock_payload:?}" "${key_payload:?}" "${disko_script:?}" "${target_system:?}"
: "${uses_existing_partitions:?}" "${is_apple_silicon:?}"
: "${target_disk=}" "${target_efi=}" "${target_root=}" "${target_swap=}" "${state_backup=}"

installer_identity="/run/$host_name-installer.agekey"
identity="/run/$host_name-host.agekey"

cleanup() {
  rm -f "$installer_identity" "$identity"
}
trap cleanup EXIT

printf '%s\n' \
  "Offline NixOS installer for $host_name" \
  '========================================' \
  "" \
  "This will erase $erase_description." \
  ""

udevadm settle
if [[ "$uses_existing_partitions" == true ]]; then
  for device in "$target_efi" "$target_root" "$target_swap"; do
    if [[ ! -b "$device" ]]; then
      printf 'Configured partition is missing: %s\n' "$device" >&2
      exit 1
    fi
  done

  if [[ "$is_apple_silicon" == true ]]; then
    asahi_esp_uuid="$(tr -d '\0' </proc/device-tree/chosen/asahi,efi-system-partition)"
    asahi_esp="$(readlink -f "/dev/disk/by-partuuid/$asahi_esp_uuid")"
    configured_esp="$(readlink -f "$target_efi")"
    if [[ -z "$asahi_esp" || "$configured_esp" != "$asahi_esp" ]]; then
      printf 'Configured EFI partition %s is not the Asahi EFI partition %s.\n' \
        "$configured_esp" "$asahi_esp" >&2
      exit 1
    fi
  fi

  printf 'Configured partitions:\n'
  lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS \
    "$(readlink -f "$target_efi")" \
    "$(readlink -f "$target_root")" \
    "$(readlink -f "$target_swap")"
else
  if [[ ! -b "$target_disk" ]]; then
    printf 'Configured target disk is missing: %s\n' "$target_disk" >&2
    exit 1
  fi
  if [[ "$(lsblk -dnro TYPE "$target_disk")" != disk ]]; then
    printf 'Configured target is not a whole disk: %s\n' "$target_disk" >&2
    exit 1
  fi

  target_real="$(readlink -f "$target_disk")"
  installer_source="$(findmnt -nro SOURCE /iso)"
  installer_real="$(readlink -f "$installer_source")"
  installer_parent="$(lsblk -ndo PKNAME "$installer_real" 2>/dev/null || true)"
  if [[ -n "$installer_parent" ]]; then
    installer_real="$(readlink -f "/dev/$installer_parent")"
  fi
  if [[ "$target_real" == "$installer_real" ]]; then
    printf 'Configured target disk is the installer USB: %s\n' "$target_real" >&2
    exit 1
  fi

  printf 'Configured target disk:\n'
  lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,PARTLABEL,MODEL,TRAN,MOUNTPOINTS "$target_real"
fi

printf '\nUnlock the encrypted installer payloads. No disk changes have been made yet.\n'
umask 077
age --decrypt --output "$installer_identity" "$unlock_payload"
age --decrypt --identity "$installer_identity" --output "$identity" "$key_payload"
actual_recipient="$(age-keygen -y "$identity")"
if [[ "$actual_recipient" != "$expected_recipient" ]]; then
  printf 'Host identity recipient mismatch: expected %s, got %s.\n' \
    "$expected_recipient" "$actual_recipient" >&2
  exit 1
fi

printf '\nType ERASE %s to continue: ' "$host_name"
read -r confirmation
if [[ "$confirmation" != "ERASE $host_name" ]]; then
  printf 'Installation cancelled.\n'
  exit 1
fi

if [[ "$uses_existing_partitions" == true ]]; then
  wipefs --all "$target_root"
  wipefs --all "$target_swap"
  udevadm settle
fi

"$disko_script"
# chmod 0755 /mnt

if [[ -n "$state_backup" ]]; then
  printf '\nRestoring the encrypted home and persisted system-state archive.\n'
  age --decrypt --identity "$installer_identity" "$state_backup" |
    zstd --decompress --stdout |
    tar --extract --directory=/mnt --acls --xattrs --numeric-owner --same-owner --same-permissions
fi

install -d -m 700 /mnt/persist/etc/agenix
install -m 600 "$identity" /mnt/persist/etc/agenix/host.agekey

nixos-install --root /mnt --system "$target_system" --no-channel-copy --no-root-password

# chmod 0755 /mnt /mnt/nix /mnt/persist /mnt/etc /mnt/persist/var /mnt/persist/var/lib

sync
printf '\nInstallation complete. Remove the USB drive, then press Enter to reboot.\n'
read -r _
systemctl reboot
