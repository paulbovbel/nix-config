{
  lib,
  asahi-vendor-firmware,
  nixos-apple-silicon,
  ...
}: {
  imports = [
    nixos-apple-silicon.nixosModules.default
  ];

  hardware.asahi = {
    enable = true;
    extractPeripheralFirmware = true;
    peripheralFirmwareDirectory = asahi-vendor-firmware;
  };

  hardware.apple.touchBar = {
    enable = true;
  };

  rootFs.existingPartitions = {
    efiDevice = "/dev/disk/by-partlabel/disk-main-ESP";
    swapDevice = "/dev/disk/by-partlabel/disk-main-swap";
    rootDevice = "/dev/disk/by-partlabel/disk-main-root";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
