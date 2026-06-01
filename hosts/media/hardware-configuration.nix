# Dummy hardware configuration for the media host.
{lib, ...}: {
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_BOOT";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [];
}
