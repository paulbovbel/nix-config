{ config, pkgs, ... }:

let
  inhibitSleepWhileSshScript = ./inhibit-sleep-while-ssh.sh;
  disableWakeSourcesScript = ./disable-wake-sources.sh;
  resumeSleepInhibitScript = ./resume-sleep-inhibit.sh;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    # package = config.boot.kernelPackages.nvidiaPackages.latest;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
  };

  boot.extraModprobeConfig = ''
    options nvidia NVreg_PreserveVideoMemoryAllocations=1
    options nvidia NVreg_TemporaryFilePath=/var/tmp
  '';

  boot.kernelParams = [
    # Prefer deep suspend (S3) over s2idle when available.
    "mem_sleep_default=deep"
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];

  systemd.tmpfiles.rules = [
    "d /var/tmp 1777 root root -"
  ];

  systemd.services.nvidia-suspend.enable = true;
  systemd.services.nvidia-resume.enable = true;
  systemd.services.nvidia-hibernate.enable = true;

  networking.hostName = "white-tower";
  networking.networkmanager.enable = true;

  system.stateVersion = "26.05";

  # Sleep hacks

  systemd.services.disable-wake-sources = {
    description = "Disable wake sources except power buttons";
    wantedBy = [ "multi-user.target" "sleep.target" ];
    before = [ "sleep.target" ];
    serviceConfig.Type = "oneshot";
    script = builtins.readFile disableWakeSourcesScript;
    path = [ pkgs.coreutils pkgs.gnugrep pkgs.iproute2 pkgs.ethtool ];
  };

  # for some reason this host goes back to sleep immediately after resume
  services.logind.settings.Login = {
    IdleAction = "ignore";
  };

  # more inhibit sleep after resume hacks
  systemd.services.resume-sleep-inhibit = {
    description = "Block suspend briefly after resume";
    wantedBy = [ "post-resume.target" ];
    after = [ "post-resume.target" ];
    path = [ pkgs.systemd pkgs.coreutils ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${resumeSleepInhibitScript}";
    };
  };

  # inhibit sleep while SSH sessions are active to prevent accidental disconnects of remote sessions
  systemd.services.inhibit-sleep-while-ssh = {
    description = "Inhibit sleep while SSH sessions are active";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ pkgs.systemd pkgs.bash pkgs.procps pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
      ExecStart = "${pkgs.bash}/bin/bash ${inhibitSleepWhileSshScript}";
    };
  };

  }
