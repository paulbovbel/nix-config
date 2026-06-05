{pkgs, ...}: {
  imports = [
    ../graphical
  ];

  disko.devices.zpool.zroot.datasets = {
    "root/steam-library" = {
      type = "zfs_fs";
      mountpoint = "/steam-library";
      options."com.sun:auto-snapshot" = "false";
    };
  };

  systemd.tmpfiles.rules = [
    "d /steam-library 2775 root users - -"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraPackages = [
      pkgs.pulseaudio
    ];
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        softrealtime = "auto";
        inhibit_screensaver = 1;
      };
      cpu = {
        governor = "performance";
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1;
      };
    };
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud
    goverlay
    gamescope
    protonup-qt
    lutris
  ];
}
