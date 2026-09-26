#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if (($# < 2)); then
  printf 'Usage: %s <host> <reuse|new> [nix build options...]\n' "$0" >&2
  exit 2
fi
host="$1"
key_mode="$2"
shift 2
payload="$repo/secrets/installer/$host-host.agekey.age"
unlock_payload="$repo/secrets/installer/$host-installer.agekey.age"
installer_recipient_path="$repo/secrets/installer/$host-installer-recipient"

case "$key_mode" in
reuse | new) ;;
*)
  printf 'Key mode must be reuse or new, got: %s\n' "$key_mode" >&2
  exit 2
  ;;
esac

NIX_CONFIG_BRANCH="$(git -C "$repo" branch --show-current)"
NIX_CONFIG_REVISION="$(git -C "$repo" rev-parse HEAD)"
if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
  NIX_CONFIG_REVISION+="-dirty"
  printf 'Warning: building from a dirty working tree; automatic upgrades will be disabled until a clean configuration is activated.\n' >&2
fi
export NIX_CONFIG_BRANCH NIX_CONFIG_REVISION
if [[ -z "$NIX_CONFIG_BRANCH" ]]; then
  printf 'Cannot build an installer from a detached HEAD.\n' >&2
  exit 1
fi

export NIXOS_INSTALLER_FLAKE="path:$repo"
export NIXOS_INSTALLER_HOST="$host"
export NIXOS_INSTALLER_KEY_PAYLOAD="$payload"
export NIXOS_INSTALLER_UNLOCK_PAYLOAD="$unlock_payload"
export NIXOS_INSTALLER_FIRMWARE=""
export NIXOS_INSTALLER_HOME_BACKUP=""

temporary_directory="$(mktemp -d --tmpdir "${host}-installer.XXXXXXXX")"
cleanup_temporary_directory() {
  rm -rf -- "$temporary_directory" || sudo rm -rf -- "$temporary_directory"
}
trap cleanup_temporary_directory EXIT

target_system="$(nix eval --impure --raw "$NIXOS_INSTALLER_FLAKE#nixosConfigurations.$host.config.nixpkgs.hostPlatform.system")"
if [[ "$target_system" == aarch64-linux ]]; then
  firmware_directory="$temporary_directory/vendorfw"
  mkdir "$firmware_directory"
  sudo cp -a /boot/vendorfw/. "$firmware_directory/"
  sudo chown -R "$(id -u):$(id -g)" "$firmware_directory"
  export NIXOS_INSTALLER_FIRMWARE="$firmware_directory"
fi

"$repo/installer/prepare-key.py" "$host" "$key_mode"
installer_recipient="$(<"$installer_recipient_path")"

if [[ "$host" == "$(hostname)" ]]; then
  printf "Embed encrypted application state from this host's home directories? [y/N] "
  backup_homes=""
  if read -r backup_homes && [[ "$backup_homes" == y || "$backup_homes" == Y ]]; then
    printf 'Close other graphical applications before archiving? [y/N] '
    close_apps=""
    if read -r close_apps && [[ "$close_apps" == y || "$close_apps" == Y ]]; then
      "$repo/installer/close-graphical-apps.sh"
    fi
    mapfile -t home_users < <(
      nix eval --impure --raw \
        "$NIXOS_INSTALLER_FLAKE#nixosConfigurations.$host.config.rootFs.homeUsers" \
        --apply 'builtins.concatStringsSep "\n"'
    )
    home_backup="$temporary_directory/homes.tar.zst.age"
    "$repo/installer/prepare-homes.sh" \
      "$home_backup" \
      "$installer_recipient" \
      "${home_users[@]}"
    export NIXOS_INSTALLER_HOME_BACKUP="$home_backup"
  fi
fi

# The Nix expression intentionally reads values from the exported environment.
# shellcheck disable=SC2016
nix build --impure --out-link "$repo/result" --expr '
  let
    flake = builtins.getFlake (builtins.getEnv "NIXOS_INSTALLER_FLAKE");
    hostName = builtins.getEnv "NIXOS_INSTALLER_HOST";
    keyPayload = builtins.path {
      path = builtins.getEnv "NIXOS_INSTALLER_KEY_PAYLOAD";
      name = "${hostName}-host.agekey.age";
    };
    unlockPayload = builtins.path {
      path = builtins.getEnv "NIXOS_INSTALLER_UNLOCK_PAYLOAD";
      name = "${hostName}-installer.agekey.age";
    };
    firmwarePath = builtins.getEnv "NIXOS_INSTALLER_FIRMWARE";
    firmwareDirectory =
      if firmwarePath == ""
      then null
      else builtins.path {
        path = firmwarePath;
        name = "${hostName}-vendorfw";
      };
    homeBackupPath = builtins.getEnv "NIXOS_INSTALLER_HOME_BACKUP";
    homeBackup =
      if homeBackupPath == ""
      then null
      else builtins.path {
        path = homeBackupPath;
        name = "${hostName}-homes.tar.zst.age";
      };
  in
    (flake.lib.mkInstaller { inherit firmwareDirectory homeBackup hostName keyPayload unlockPayload; }).config.system.build.isoImage
' "$@"

printf 'Installer image:\n'
printf '  %s\n' "$repo"/result/iso/*.iso
