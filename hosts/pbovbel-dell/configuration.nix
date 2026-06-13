{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking.hostName = "pbovbel-dell";

  services = {
    thermald.enable = true;
    power-profiles-daemon.enable = true;
  };

  impermanenceRoot = {
    diskId = "/dev/disk/by-id/nvme-Sabrent_Rocket_4.0_2TB_7A0F07181E3D00004779";
    swapSize = "32G";
  };

  nvidia.prime = {
    enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  system.stateVersion = "26.05";
}
