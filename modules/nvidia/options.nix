{lib, ...}: {
  options.nvidia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Configure the proprietary NVIDIA userspace driver and kernel module.";
    };

    open = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use NVIDIA's open-source kernel modules instead of the proprietary kernel modules.";
    };

    bleedingEdge = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use nixpkgs unstable's bleeding-edge NVIDIA driver instead of the production branch.";
    };

    prime = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Configure NVIDIA PRIME on a host with integrated and discrete GPUs.";
      };

      offload.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use PRIME render offload instead of a permanently active discrete GPU.";
      };

      offload.enableOffloadCmd = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the nvidia-offload helper for launching applications on the discrete GPU.";
      };

      intelBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:0:2:0";
        description = "PCI bus ID of the Intel integrated GPU used by PRIME.";
      };

      amdgpuBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:5:0:0";
        description = "PCI bus ID of the AMD integrated GPU used by PRIME.";
      };

      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:1:0:0";
        description = "PCI bus ID of the discrete NVIDIA GPU used by PRIME.";
      };
    };
  };
}
