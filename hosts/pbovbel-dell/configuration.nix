{pkgs, ...}: {
  imports = [
    ../site.nix
    ./hardware-configuration.nix
    ./robot-demo.nix
  ];

  boot = {
    initrd.systemd.enable = true;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages;
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

  grafanaCloud.role = "laptop";

  rootFs = {
    enable = true;
    backend = "zfs";
    impermanent = true;
    swapSize = "32G";
  };

  system.stateVersion = "26.05";

  netboot = {
    enable = true;
  };
}
