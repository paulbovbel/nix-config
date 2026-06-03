{lib, ...}: {
  options.nvidia.sleep.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable NVIDIA sleep, suspend, hibernate, and wake-inhibit integration.";
  };
}
