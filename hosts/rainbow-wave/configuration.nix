{pkgs, ...}: {
  imports = [
    ../site.nix
    ./hardware-configuration.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # TODO try CachyOS kernel for gaming performance?
    kernelPackages = pkgs.linuxPackages;
  };

  networking = {
    hostName = "rainbow-wave";
    hostId = "4619f943";
  };

  rootZfs = {
    enable = true;
    impermanent = true;
    swapSize = "8G";
  };

  nvidia.enable = true;

  system.stateVersion = "26.05";

  netboot = {
    enable = true;
    installLegacyImage = true;
  };
}
