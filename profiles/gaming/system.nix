{pkgs, ...}: {
  imports = [
    ../graphical/system.nix
  ];

  rootFs.volumes.steam-library = {
    mountpoint = "/steam-library";
    autoSnapshot = false;
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
    protontricks.enable = true;
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

  services.pipewire.extraConfig.pipewire."10-fix-crackling" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 1024;
      "default.clock.min-quantum" = 32;
      "default.clock.max-quantum" = 4096;
    };
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true;
    package = pkgs.sunshine.override {cudaSupport = true;};

    settings = {
      port = 47989;

      capture = "kms";
      encoder = "nvenc";
      hevc_mode = 3;
      av1_mode = 1;

      nvenc_preset = 5;
      nvenc_twopass = "quarter_res";
      nvenc_spatial_aq = "enabled";
      nvenc_vbv_increase = 200;

      max_bitrate = 150000;
      minimum_fps_target = 60;
      lan_encryption_mode = 0;
    };

    applications = {
      env.PATH = "$(PATH):$(HOME)/.local/bin";
      apps = [
        {
          name = "Desktop";
          image-path = "desktop.png";
        }
        {
          name = "Steam Big Picture";
          detached = [
            "setsid /run/current-system/sw/bin/steam steam://open/bigpicture"
          ];
          prep-cmd = [
            {
              do = "";
              undo = "setsid /run/current-system/sw/bin/steam steam://close/bigpicture";
            }
          ];
          image-path = "steam.png";
        }
        {
          name = "Heroic";
          detached = [
            "${pkgs.heroic}/bin/heroic"
          ];
        }
        {
          name = "Lutris";
          detached = [
            "${pkgs.lutris}/bin/lutris"
          ];
        }
        {
          name = "PrismLauncher";
          detached = [
            "${pkgs.prismlauncher}/bin/prismlauncher"
          ];
        }
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    mangohud
    goverlay
    gamescope
    heroic
    protonup-qt
    lutris
    prismlauncher
  ];
}
