{lib, ...}: {
  options.nvidia = {
    sleep.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NVIDIA sleep, suspend, hibernate, and wake-inhibit integration.";
    };

    prime = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NVIDIA PRIME for hybrid graphics.";
      };

      offload.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NVIDIA PRIME render offload mode.";
      };

      offload.enableOffloadCmd = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the nvidia-offload command for NVIDIA PRIME render offload.";
      };

      intelBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:0:2:0";
        description = "Intel GPU bus ID for NVIDIA PRIME.";
      };

      amdgpuBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:5:0:0";
        description = "AMD GPU bus ID for NVIDIA PRIME.";
      };

      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:1:0:0";
        description = "NVIDIA GPU bus ID for NVIDIA PRIME.";
      };
    };
  };
}
