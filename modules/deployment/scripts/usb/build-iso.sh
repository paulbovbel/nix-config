#!/usr/bin/env bash
set -euo pipefail

if (($# < 1)); then
  printf 'Usage: %s <host> [--state ARCHIVE.age] [nix build options...]\n' "$0" >&2
  exit 2
fi
host="$1"
shift
# shellcheck source=modules/deployment/scripts/source.sh
source "$(dirname "${BASH_SOURCE[0]}")/../source.sh"
payload="$repo/secrets/installer/$host-host.agekey.age"
unlock_payload="$repo/secrets/installer/$host-installer.agekey.age"
if [[ ! -f "$payload" || ! -f "$unlock_payload" ]]; then
  printf 'Prepare the identity first: just installer key %s reuse|new\n' "$host" >&2
  exit 1
fi

export NIXOS_INSTALLER_FLAKE="path:$repo"
export NIXOS_INSTALLER_HOST="$host"
export NIXOS_INSTALLER_KEY_PAYLOAD="$payload"
export NIXOS_INSTALLER_UNLOCK_PAYLOAD="$unlock_payload"
export NIXOS_INSTALLER_FIRMWARE=""
export NIXOS_INSTALLER_STATE_BACKUP=""
build_options=()
while (($#)); do
  case "$1" in
  --state)
    if (($# < 2)) || [[ ! -f "$2" ]]; then
      printf '%s requires an existing encrypted archive\n' "$1" >&2
      exit 2
    fi
    NIXOS_INSTALLER_STATE_BACKUP="$(realpath "$2")"
    shift 2
    ;;
  *)
    build_options+=("$1")
    shift
    ;;
  esac
done

temporary_directory="$(mktemp -d --tmpdir "${host}-installer.XXXXXXXX")"
cleanup_temporary_directory() {
  rm -rf -- "$temporary_directory" || sudo rm -rf -- "$temporary_directory"
}
trap cleanup_temporary_directory EXIT

installer_kind="$(nix eval --impure --raw "$NIXOS_INSTALLER_FLAKE#lib.hosts.$host.installer")"
if [[ "$installer_kind" == apple-silicon ]]; then
  firmware_directory="$temporary_directory/vendorfw"
  mkdir "$firmware_directory"
  sudo cp -a /boot/vendorfw/. "$firmware_directory/"
  sudo chown -R "$(id -u):$(id -g)" "$firmware_directory"
  export NIXOS_INSTALLER_FIRMWARE="$firmware_directory"
fi

# The Nix expression intentionally reads values from the exported environment.
# shellcheck disable=SC2016
nix build --impure --out-link "$repo/result-installer-$host" --expr '
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
    stateBackupPath = builtins.getEnv "NIXOS_INSTALLER_STATE_BACKUP";
    stateBackup =
      if stateBackupPath == ""
      then null
      else builtins.path {
        path = stateBackupPath;
        name = "${hostName}-state.tar.zst.age";
      };
  in
    (flake.lib.mkInstaller { inherit firmwareDirectory hostName keyPayload stateBackup unlockPayload; }).config.system.build.isoImage
' "${build_options[@]}"

printf 'Installer image:\n'
printf '  %s\n' "$repo"/result-installer-"$host"/iso/*.iso
