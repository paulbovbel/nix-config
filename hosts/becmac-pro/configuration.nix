{...}: {
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

  rootZfs = {
    enable = true;
    arcMaxPercent = 25;
    encrypted = false;
    impermanent = true;
  };

  system.stateVersion = "26.05";
}
