{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.netboot;
in {
  options.netboot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install netboot.xyz into the systemd-boot ESP when systemd-boot is enabled.";
    };

    installLegacyImage = lib.mkEnableOption "installing the netboot.xyz legacy to fix USB keyboard";
  };

  config.boot.loader.systemd-boot = lib.mkIf (cfg.enable && config.boot.loader.systemd-boot.enable) {
    extraFiles =
      {
        "EFI/netboot/netboot.xyz.efi" = pkgs.netbootxyz-efi.outPath;
      }
      // lib.optionalAttrs cfg.installLegacyImage {
        "EFI/netboot/netboot.xyz-legacy.efi" = pkgs.netbootxyz-legacy.outPath;
      };

    extraEntries."netboot-xyz.conf" = ''
      title netboot.xyz
      efi /EFI/netboot/netboot.xyz.efi
    '';
  };
}
