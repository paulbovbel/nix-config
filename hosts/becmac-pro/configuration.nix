{
  config,
  pkgs,
  tiny-dfr-nyan,
  ...
}: let
  colors = config.lib.stylix.colors;
in {
  imports = [
    ../site.nix
    ./hardware-configuration.nix
  ];

  boot = {
    initrd.systemd.enable = true;
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 3;
      efi.canTouchEfiVariables = false;
    };
    zfs.forceImportRoot = false;
  };

  networking = {
    hostName = "becmac-pro";
    hostId = "6d616362";
    networkmanager.wifi.backend = "iwd";
  };

  home-manager.sharedModules = [
    {
      dconf.settings."org/gnome/desktop/input-sources".xkb-options = ["altwin:swap_alt_win"];
    }
  ];

  hardware.apple.touchBar.package = tiny-dfr-nyan.lib.mkTintedPackage {
    inherit pkgs;
    colors = {
      background = "#${colors.base00}";
      inactive = "#${colors.base02}";
      active = "#${colors.base0E}";
      foreground = "#${colors.base05}";
      charging = "#${colors.base0B}";
      low = "#${colors.base08}";
    };
  };

  rootZfs = {
    enable = true;
    arcMaxPercent = 25;
    encrypted = false;
    impermanent = true;
  };

  system.stateVersion = "26.05";
}
