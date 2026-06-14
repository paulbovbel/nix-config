{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking = {
    hostName = "pbovbel-dell";
    hostId = "8f2543e6";
  };

  services = {
    thermald.enable = true;
    power-profiles-daemon.enable = true;
  };

  impermanenceRoot = {
    enable = true;
    swapSize = "32G";
  };

  nvidia.enable = true;

  system.stateVersion = "26.05";
}
