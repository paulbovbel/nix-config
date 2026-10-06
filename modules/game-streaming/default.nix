{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gameStreaming;
in {
  imports = [./options.nix];
  config = lib.mkMerge [
    {
      moduleDocumentation.game-streaming = {
        title = "Game Streaming";
        category = "Applications";
        summary = "Host-selected Sunshine streaming and shared application menu.";
      };
    }
    (lib.mkIf cfg.enable {
      services.sunshine = {
        enable = true;
        autoStart = true;
        openFirewall = true;
        capSysAdmin = true;
        package = lib.mkDefault (pkgs.sunshine.override {cudaSupport = cfg.encoder == "nvenc";});
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
          // lib.optionalAttrs (cfg.encoder == "nvenc") {
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
