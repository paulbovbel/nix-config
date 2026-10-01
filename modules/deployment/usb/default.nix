{
  expectedRecipient,
  isAppleSilicon,
  keyPayload,
  lib,
  pkgs,
  stateBackup,
  targetSystem,
  unlockPayload,
  ...
}: let
  target = targetSystem.config;
  hostName = target.networking.hostName;
  system = target.nixpkgs.hostPlatform.system;
  partitions = target.rootFs.existingPartitions;
  usesExistingPartitions = partitions != null;
  targetSystemPath = target.system.build.toplevel;
  diskoScript = target.system.build.diskoScript;
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
      ++ lib.optionals (stateBackup != null) [
        pkgs.gnutar
        pkgs.zstd
      ];
    text = let
      variables = {
        host_name = hostName;
        erase_description = eraseDescription;
        uses_existing_partitions = lib.boolToString usesExistingPartitions;
        is_apple_silicon = lib.boolToString isAppleSilicon;
        target_disk =
          if usesExistingPartitions
          then ""
          else target.rootFs.diskId;
        target_efi =
          if usesExistingPartitions
          then partitions.efiDevice
          else "";
        target_root =
          if usesExistingPartitions
          then partitions.rootDevice
          else "";
        target_swap =
          if usesExistingPartitions
          then partitions.swapDevice
          else "";
        unlock_payload = toString unlockPayload;
        key_payload = toString keyPayload;
        expected_recipient = expectedRecipient;
        disko_script = toString diskoScript;
        state_backup =
          if stateBackup == null
          then ""
          else toString stateBackup;
        target_system = toString targetSystemPath;
      };
    in
      lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name}=${lib.escapeShellArg value}") variables)
      + "\n"
      + builtins.readFile ../scripts/usb/install-host.sh;
  };
  installerShell = pkgs.writeShellScriptBin "installer-shell" ''
    if [ "$(${pkgs.coreutils}/bin/tty)" = /dev/tty1 ]; then
      ${lib.getExe installHost}
    fi
    exec ${lib.getExe pkgs.bashInteractive} -l
  '';
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
      ++ lib.optional (stateBackup != null) stateBackup;
  };

  boot.supportedFilesystems = lib.mkOverride 40 target.boot.supportedFilesystems;

  networking.hostName = "${hostName}-installer";
  services.getty.autologinUser = lib.mkForce "root";
  users.users.root.shell = "${installerShell}/bin/installer-shell";

  environment.systemPackages = [installHost];
}
