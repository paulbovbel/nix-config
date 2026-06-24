{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.netboot;

  netbootImage =
    if cfg.installLegacyImage
    then pkgs.netbootxyz-legacy
    else pkgs.netbootxyz-efi;

  netbootEfiPath =
    if cfg.installLegacyImage
    then "EFI/netboot/netboot.xyz-legacy.efi"
    else "EFI/netboot/netboot.xyz.efi";

  espMountPoint = config.boot.loader.efi.efiSysMountPoint;
in {
  options.netboot = {
    enable = lib.mkEnableOption "netboot.xyz boot entry";

    installLegacyImage = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the legacy netboot.xyz EFI image instead of the standard EFI image.";
    };
  };

  config = lib.mkIf (cfg.enable && config.boot.loader.systemd-boot.enable) {
    boot.loader.systemd-boot = {
      extraFiles = {
        "${netbootEfiPath}" = netbootImage.outPath;
      };

      extraEntries."netboot-xyz.conf" = ''
        title netboot.xyz
        efi /${netbootEfiPath}
      '';
    };

    system.activationScripts.cleanupOldNetbootImages = ''
      netboot_dir=${lib.escapeShellArg "${espMountPoint}/EFI/netboot"}
      keep=${lib.escapeShellArg (baseNameOf netbootEfiPath)}

      if [ -d "$netboot_dir" ]; then
        find "$netboot_dir" \
          -maxdepth 1 \
          -type f \
          -name 'netboot.xyz*.efi' \
          ! -name "$keep" \
          -delete
      fi
    '';
  };
}
