{
  config,
  pkgs,
  ...
}: let
  inhibitSleepWhileSshScript = ./inhibit-sleep-while-ssh.sh;
  disableWakeSourcesScript = ./disable-wake-sources.sh;
  resumeSleepInhibitScript = ./resume-sleep-inhibit.sh;
in {
  services = {
    xserver.videoDrivers = ["nvidia"];
    logind.settings.Login = {
      IdleAction = "ignore";
    };
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    # Beta driver often carries suspend/resume and Wayland fixes sooner.
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
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

      inhibit-sleep-while-ssh = {
        description = "Inhibit sleep while SSH sessions are active";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        path = [pkgs.systemd pkgs.bash pkgs.procps pkgs.coreutils pkgs.gnugrep];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = 5;
          ExecStart = "${pkgs.bash}/bin/bash ${inhibitSleepWhileSshScript}";
        };
      };
    };
  };
}
