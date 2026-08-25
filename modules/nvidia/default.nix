{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nvidia;
in {
  imports = [./options.nix];

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.xserver.videoDrivers = ["nvidia"];

      hardware.nvidia = {
        modesetting.enable = true;
        inherit (cfg) open;
        nvidiaSettings = true;
        package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.latest;
        # package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        #   version = "610.57.04";
        #   sha256_64bit = "sha256-suk1xmuDuwDAyFe8jg7g/VLekoa0DJzB7sKafOfrEW0=";
        #   openSha256 = "sha256-rQHOOOY4KL92Ww3KDwh+j4eGU7oNAH8LutZC5wmFnPo=";
        #   settingsSha256 = "sha256-ZEMo8I8Zc2Tq6RVDNYpAH+f094dUaZiBqO+5f6lIjRI=";
        #   persistencedSha256 = "sha256-aXmD2VY1RLlgAnlHhOUMWzvMyhI6JTClcFLm4imF/mA=";
        # };
        powerManagement.enable = true;
        powerManagement.finegrained = lib.mkDefault false;
      };

      hardware.graphics.extraPackages = [
        pkgs.nvidia-vaapi-driver
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
