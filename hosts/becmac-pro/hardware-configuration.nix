{
  lib,
  nixos-apple-silicon,
  ...
}: {
  imports = [
    nixos-apple-silicon.nixosModules.default
  ];

  boot.supportedFilesystems = ["zfs"];

  hardware.asahi = {
    enable = true;
    extractPeripheralFirmware = true;
    peripheralFirmwareDirectory = /boot/vendorfw;
  };

  hardware.apple.touchBar = {
    enable = true;
  };

  rootZfs.existingPartitions = {
    efiDevice = "/dev/disk/by-partlabel/disk-main-ESP";
    swapDevice = "/dev/disk/by-partlabel/disk-main-swap";
    zfsDevice = "/dev/disk/by-partlabel/disk-main-root";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
