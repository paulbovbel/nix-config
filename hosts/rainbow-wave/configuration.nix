{pkgs, ...}: {
  userProfiles = {
    abovbel = ["gaming"];
    pbovbel = ["gaming"];
  };
  imports = [
    ../site.nix
    ./hardware-configuration.nix
  ];

  boot = {
    initrd.systemd.enable = true;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages;
  };

  networking = {
    hostName = "rainbow-wave";
    hostId = "4619f943";
    interfaces.enp42s0.wakeOnLan = {
      enable = true;
      policy = ["magic"];
    };
  };

  rootFs = {
    enable = true;
    backend = "zfs";
    impermanent = true;
    swapSize = "8G";
  };

  autoUpgrade.enable = true;

  system.stateVersion = "26.05";

  netboot = {
    enable = true;
    installLegacyImage = true;
  };
}
