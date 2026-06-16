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

  environment.systemPackages = [pkgs.intel-gpu-tools];

  impermanenceRoot = {
    enable = true;
    swapSize = "32G";
  };

  nvidia = {
    enable = true;
    open = false;
  };

  system.stateVersion = "26.05";
}
