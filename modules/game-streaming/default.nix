{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gameStreaming;
  nvenc = cfg.encoder == "nvenc";
  inhibitSunshine = pkgs.writeShellApplication {
    name = "inhibit-sleep-while-sunshine";
    runtimeInputs = [pkgs.systemd pkgs.coreutils pkgs.gawk];
    text = builtins.readFile ./scripts/inhibit-sleep-while-sunshine.sh;
  };
  inhibitRemotePlay = pkgs.writeShellApplication {
    name = "inhibit-sleep-while-steam-remote-play";
    runtimeInputs = [pkgs.systemd pkgs.procps pkgs.coreutils pkgs.gawk];
    text = builtins.readFile ./scripts/inhibit-sleep-while-steam-remote-play.sh;
  };
in {
  imports = [./options.nix];
  config = lib.mkMerge [
    {
      moduleDocumentation.game-streaming = {
        title = "Game Streaming";
        category = "Applications";
        summary = "Host-selected Sunshine streaming, shared application menu, and streaming sleep inhibition.";
      };
    }
    (lib.mkIf cfg.enable {
      systemd.user.services.inhibit-sleep-while-sunshine = {
        description = "Prevent sleep while Sunshine clients are connected";
        wantedBy = ["sunshine.service"];
        bindsTo = ["sunshine.service"];
        partOf = ["sunshine.service"];
        after = ["sunshine.service"];
        serviceConfig = {
          ExecStart = lib.getExe inhibitSunshine;
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      systemd.user.services.inhibit-sleep-while-steam-remote-play = {
        description = "Prevent sleep while Steam Remote Play is active";
        wantedBy = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        after = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = lib.getExe inhibitRemotePlay;
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      services.sunshine = {
        enable = true;
        autoStart = true;
        openFirewall = true;
        capSysAdmin = true;
        package = lib.mkDefault (pkgs.sunshine.override {cudaSupport = nvenc;});
        settings =
          {
            port = 47989;
            capture = "kms";
            encoder = lib.mkIf (cfg.encoder != null) cfg.encoder;
            hevc_mode = 3;
            av1_mode = 1;
            max_bitrate = 150000;
            minimum_fps_target = 60;
            lan_encryption_mode = 0;
          }
          // lib.optionalAttrs nvenc {
            nvenc_preset = 5;
            nvenc_twopass = "quarter_res";
            nvenc_spatial_aq = "enabled";
            nvenc_vbv_increase = 200;
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
              image-path = "steam.png";
              detached = ["setsid /run/current-system/sw/bin/steam steam://open/bigpicture"];
              prep-cmd = [
                {
                  do = "";
                  undo = "setsid /run/current-system/sw/bin/steam steam://close/bigpicture";
                }
              ];
            }
            {
              name = "Heroic";
              detached = ["${pkgs.heroic}/bin/heroic"];
            }
            {
              name = "Lutris";
              detached = ["${pkgs.lutris}/bin/lutris"];
            }
            {
              name = "PrismLauncher";
              detached = ["${pkgs.prismlauncher}/bin/prismlauncher"];
            }
          ];
        };
      };
    })
  ];
}
