{
  expectedRecipient,
  homeBackup,
  keyPayload,
  lib,
  pkgs,
  targetSystem,
  unlockPayload,
  ...
}: let
  target = targetSystem.config;
  hostName = target.networking.hostName;
  system = target.nixpkgs.hostPlatform.system;
  isAppleSilicon = system == "aarch64-linux";
  partitions = target.rootFs.existingPartitions;
  usesExistingPartitions = partitions != null;
  targetSystemPath = target.system.build.toplevel;
  diskoScript = target.system.build.diskoScript;
  deviceValidation =
    if usesExistingPartitions
    then ''
      target_efi=${lib.escapeShellArg partitions.efiDevice}
      target_root=${lib.escapeShellArg partitions.rootDevice}
      target_swap=${lib.escapeShellArg partitions.swapDevice}

      udevadm settle
      for device in "$target_efi" "$target_root" "$target_swap"; do
        if [ ! -b "$device" ]; then
          printf 'Configured partition is missing: %s\n' "$device" >&2
          exit 1
        fi
      done

      ${lib.optionalString isAppleSilicon ''
        asahi_esp_uuid="$(tr -d '\0' </proc/device-tree/chosen/asahi,efi-system-partition)"
        asahi_esp="$(readlink -f "/dev/disk/by-partuuid/$asahi_esp_uuid")"
        configured_esp="$(readlink -f "$target_efi")"
        if [ -z "$asahi_esp" ] || [ "$configured_esp" != "$asahi_esp" ]; then
          printf 'Configured EFI partition %s is not the Asahi EFI partition %s.\n' \
            "$configured_esp" "$asahi_esp" >&2
          exit 1
        fi
      ''}

      printf 'Configured partitions:\n'
      lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS \
        "$(readlink -f "$target_efi")" \
        "$(readlink -f "$target_root")" \
        "$(readlink -f "$target_swap")"
    ''
    else ''
      target_disk=${lib.escapeShellArg target.rootFs.diskId}

      udevadm settle
      if [ ! -b "$target_disk" ]; then
        printf 'Configured target disk is missing: %s\n' "$target_disk" >&2
        exit 1
      fi
      if [ "$(lsblk -dnro TYPE "$target_disk")" != disk ]; then
        printf 'Configured target is not a whole disk: %s\n' "$target_disk" >&2
        exit 1
      fi

      target_real="$(readlink -f "$target_disk")"
      installer_source="$(findmnt -nro SOURCE /iso)"
      installer_real="$(readlink -f "$installer_source")"
      installer_parent="$(lsblk -ndo PKNAME "$installer_real" 2>/dev/null || true)"
      if [ -n "$installer_parent" ]; then
        installer_real="$(readlink -f "/dev/$installer_parent")"
      fi
      if [ "$target_real" = "$installer_real" ]; then
        printf 'Configured target disk is the installer USB: %s\n' "$target_real" >&2
        exit 1
      fi

      printf 'Configured target disk:\n'
      lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,PARTLABEL,MODEL,TRAN,MOUNTPOINTS "$target_real"
    '';
  eraseDescription =
    if usesExistingPartitions
    then "the configured NixOS root and swap partitions"
    else "the entire configured target disk";
  installHost = pkgs.writeShellApplication {
    name = "install-${hostName}";
    runtimeInputs =
      [
        pkgs.age
        pkgs.coreutils
        pkgs.nixos-install-tools
        pkgs.systemd
        pkgs.util-linux
      ]
      ++ lib.optionals (homeBackup != null) [
        pkgs.gnutar
        pkgs.zstd
      ];
    text = ''
      installer_identity=/run/${hostName}-installer.agekey
      identity=/run/${hostName}-host.agekey

      cleanup() {
        rm -f "$installer_identity" "$identity"
      }
      trap cleanup EXIT

      clear
      printf '%s\n' \
        'Offline NixOS installer for ${hostName}' \
        '========================================' \
        "" \
        'This will erase ${eraseDescription}.' \
        ""

      ${deviceValidation}

      printf '\nUnlock the encrypted installer payloads. No disk changes have been made yet.\n'
      umask 077
      age --decrypt --output "$installer_identity" ${lib.escapeShellArg (toString unlockPayload)}
      age \
        --decrypt \
        --identity "$installer_identity" \
        --output "$identity" \
        ${lib.escapeShellArg (toString keyPayload)}
      actual_recipient="$(age-keygen -y "$identity")"
      if [ "$actual_recipient" != ${lib.escapeShellArg expectedRecipient} ]; then
        printf 'Host identity recipient mismatch: expected %s, got %s.\n' \
          ${lib.escapeShellArg expectedRecipient} "$actual_recipient" >&2
        exit 1
      fi

      printf '\nType ERASE ${hostName} to continue: '
      read -r confirmation
      if [ "$confirmation" != 'ERASE ${hostName}' ]; then
        printf 'Installation cancelled.\n'
        exit 1
      fi

      ${diskoScript}

      ${lib.optionalString (homeBackup != null) ''
        printf '\nRestoring the encrypted home application-state archive.\n'
        age \
          --decrypt \
          --identity "$installer_identity" \
          ${lib.escapeShellArg (toString homeBackup)} \
          | zstd --decompress --stdout \
          | tar \
            --extract \
            --directory=/mnt \
            --acls \
            --xattrs \
            --numeric-owner \
            --same-owner \
            --same-permissions
      ''}

      install -d -m 700 /mnt/persist/etc/agenix
      install -m 600 "$identity" /mnt/persist/etc/agenix/host.agekey

      nixos-install \
        --root /mnt \
        --system ${targetSystemPath} \
        --no-channel-copy \
        --no-root-password

      sync
      printf '\nInstallation complete. Remove the USB drive, then press Enter to reboot.\n'
      read -r _
      systemctl reboot
    '';
  };
in {
  assertions = [
    {
      assertion = lib.elem system ["aarch64-linux" "x86_64-linux"];
      message = "The offline installer supports aarch64-linux and x86_64-linux targets.";
    }
    {
      assertion = usesExistingPartitions || target.rootFs.diskId != null;
      message = "The offline installer requires existing partitions or a whole target disk.";
    }
    {
      assertion = !usesExistingPartitions || partitions.swapDevice != null;
      message = "The offline installer requires an explicit swap partition when reusing partitions.";
    }
  ];

  image.baseName = lib.mkForce "nixos-${hostName}-offline-installer";
  isoImage = {
    configurationName = hostName;
    storeContents =
      [
        diskoScript
        keyPayload
        targetSystemPath
        unlockPayload
      ]
      ++ lib.optional (homeBackup != null) homeBackup;
  };

  boot.supportedFilesystems = lib.mkOverride 40 target.boot.supportedFilesystems;

  networking.hostName = "${hostName}-installer";
  systemd.services.install-host = {
    description = "Install the offline ${hostName} system image";
    wantedBy = ["multi-user.target"];
    after = ["getty@tty1.service" "systemd-udev-settle.service"];
    wants = ["systemd-udev-settle.service"];
    serviceConfig = {
      Type = "oneshot";
      StandardInput = "tty-force";
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
    };
    script = "${lib.getExe installHost}";
  };

  environment.systemPackages = [installHost];
}
