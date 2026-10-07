{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (builtins.elem "gaming" config.systemProfiles) {
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
      extraPackages = [pkgs.pulseaudio];
    };

    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
          softrealtime = "auto";
          inhibit_screensaver = 1;
        };
        cpu.governor = "performance";
        gpu = lib.mkIf config.nvidia.enable {
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

    environment.systemPackages = with pkgs; [
      mangohud
      goverlay
      gamescope
      heroic
      protonup-qt
      lutris
      prismlauncher
    ];
  };
}
