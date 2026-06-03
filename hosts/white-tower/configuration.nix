{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking.hostName = "white-tower";
  networking.networkmanager.enable = true;

  impermanenceRoot = {
    diskId = "/dev/disk/by-id/nvme-ADATA_SX8200PNP_2K4829A5C2U1";
    swapSize = "32G";
  };

  nvidia.sleep.enable = true;

  system.stateVersion = "26.05";
}
