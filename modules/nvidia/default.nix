{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nvidia;
  disableWakeSourcesScript = ./disable-wake-sources.sh;
  resumeSleepInhibitScript = ./resume-sleep-inhibit.sh;
in {
  config = lib.mkMerge [
    {
      services.xserver.videoDrivers = ["nvidia"];

      hardware.nvidia = {
        modesetting.enable = true;
        open = true;
        nvidiaSettings = true;
        # Beta driver often carries suspend/resume and Wayland fixes sooner.
        package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.beta;
        powerManagement.enable = true;
        powerManagement.finegrained = lib.mkDefault false;
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

    (lib.mkIf cfg.sleep.enable {
      services.logind.settings.Login = {
        IdleAction = "ignore";
      };

      systemd.services = {
        disable-wake-sources = {
          description = "Disable wake sources except power buttons";
          # Apply at boot and before sleep to avoid flaky spontaneous wakeups.
          wantedBy = ["multi-user.target" "sleep.target"];
          before = ["sleep.target"];
          serviceConfig.Type = "oneshot";
          script = builtins.readFile disableWakeSourcesScript;
          path = [pkgs.coreutils pkgs.gnugrep pkgs.iproute2 pkgs.ethtool];
        };

        resume-sleep-inhibit = {
          description = "Block suspend briefly after resume";
          wantedBy = ["post-resume.target"];
          after = ["post-resume.target"];
          path = [pkgs.systemd pkgs.coreutils];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${resumeSleepInhibitScript}";
          };
        };
      };
    })

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
  ];
}
