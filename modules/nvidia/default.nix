{
  config,
  lib,
  pkgs,
  unstablePkgs,
  ...
}: let
  cfg = config.nvidia;
  inherit (unstablePkgs.linuxPackagesFor config.boot.kernelPackages.kernel) nvidiaPackages;
in {
  options.moduleDocumentation.nvidia = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "NVIDIA";
      summary = "Proprietary NVIDIA drivers and PRIME hybrid graphics.";
    };
  };

  imports = [./options.nix];

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.xserver.videoDrivers = ["nvidia"];

      hardware.nvidia = {
        modesetting.enable = true;
        inherit (cfg) open;
        nvidiaSettings = true;
        package =
          if cfg.bleedingEdge
          then nvidiaPackages.bleeding_edge
          else nvidiaPackages.production;
        powerManagement.enable = true;
        powerManagement.finegrained = lib.mkDefault false;
      };

      hardware.graphics.extraPackages = [
        pkgs.nvidia-vaapi-driver
        pkgs.nvtopPackages.nvidia
      ];

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        NVD_BACKEND = "direct";
      };

      boot.extraModprobeConfig = ''
        options nvidia NVreg_PreserveVideoMemoryAllocations=1
        options nvidia NVreg_TemporaryFilePath=/var/tmp
      '';

      boot.kernelParams = [
        "mem_sleep_default=deep"
        "nvidia_drm.modeset=1"
        "nvidia_drm.fbdev=1"
      ];

      systemd = {
        tmpfiles.rules = [
          "d /var/tmp 1777 root root -"
        ];

        services = {
          nvidia-suspend.enable = true;
          nvidia-resume.enable = true;
          nvidia-hibernate.enable = true;
        };
      };
    }

    (lib.mkIf cfg.prime.enable {
      hardware.nvidia = {
        powerManagement.finegrained = true;

        prime = {
          inherit (cfg.prime) intelBusId amdgpuBusId nvidiaBusId;
          offload = {
            inherit (cfg.prime.offload) enable enableOffloadCmd;
          };
        };
      };
    })
  ]);
}
