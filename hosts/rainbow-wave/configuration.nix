{pkgs, ...}: {
  imports = [
    ../site.nix
    ./hardware-configuration.nix
  ];

  boot = {
    initrd.systemd.enable = true;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # TODO try CachyOS kernel for gaming performance?
    kernelPackages = pkgs.linuxPackages;
  };

  networking = {
    hostName = "rainbow-wave";
    hostId = "4619f943";
    interfaces.enp6s0.wakeOnLan = {
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

  system.stateVersion = "26.05";

  netboot = {
    enable = true;
    installLegacyImage = true;
  };
}
