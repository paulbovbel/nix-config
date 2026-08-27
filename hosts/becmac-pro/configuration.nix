{
  lib,
  nixos-apple-silicon,
  pkgs,
  ...
}: {
  imports = [
    ../site.nix
    nixos-apple-silicon.nixosModules.default
  ];

  boot = {
    initrd.systemd.enable = true;
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 3;
      efi.canTouchEfiVariables = false;
    };
    supportedFilesystems = ["zfs"];
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

  hardware.asahi = {
    enable = true;
    extractPeripheralFirmware = true;
    peripheralFirmwareDirectory = /boot/vendorfw;
  };

  hardware.apple.touchBar = {
    enable = true;
    package = pkgs.tiny-dfr;
  };

  rootZfs = {
    enable = true;
    arcMaxPercent = 25;
    encrypted = false;
    impermanent = true;
    existingPartitions = {
      efiDevice = "/dev/disk/by-partlabel/disk-main-ESP";
      swapDevice = "/dev/disk/by-partlabel/disk-main-swap";
      zfsDevice = "/dev/disk/by-partlabel/disk-main-root";
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  system.stateVersion = "26.05";
}
