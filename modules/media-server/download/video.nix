{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  containerUser = "${toString user.uid}:${toString user.gid}";
  popularVideosCfg = cfg.downloads.popularVideos;
  popularVideosEnabled = popularVideosCfg.channels != [];
  popularVideosPython = pkgs.python314.withPackages (python-pkgs: [
    python-pkgs.aiohttp
    python-pkgs.bgutil-ytdlp-pot-provider
    python-pkgs.pillow
    python-pkgs.yt-dlp
  ]);
  downloadPopularVideos = pkgs.writeShellApplication {
    name = "download-popular-videos";
    runtimeInputs = [pkgs.ffmpeg popularVideosPython];
    text = ''
      exec ${lib.getExe popularVideosPython} ${./download-popular-videos.py} "$@"
    '';
  };
in {
  config = lib.mkIf cfg.downloads.enable {
    age.secrets.youtube-api-key = lib.mkIf popularVideosEnabled {
      file = ../../../secrets/server/youtube-api-key.age;
    };

    storage.datasets.app.children = {
      bazarr = {};
      maintainerr = {};
      # pinchflat = {};
      radarr = {};
      sonarr = {};
    };

    storage.datasets.media.children.youtube.options.recordsize = "1M";

    systemd = lib.mkIf popularVideosEnabled {
      services.download-popular-videos = {
        description = "Download popular YouTube channel videos";
        wants = ["network-online.target"];
        after = ["network-online.target" "bgutil-ytdlp-pot-provider.service"];
        requires = ["bgutil-ytdlp-pot-provider.service"];
        unitConfig.RequiresMountsFor = [datasets.media.children.youtube.path];
        serviceConfig = {
          Type = "oneshot";
          User = user.name;
          Group = user.group;
          EnvironmentFile = config.age.secrets.youtube-api-key.path;
        };
        script = ''
          ${lib.escapeShellArgs [
            (lib.getExe downloadPopularVideos)
            (builtins.toJSON popularVideosCfg.channels)
            "${datasets.media.children.youtube.path}/popular"
          ]}
        '';
      };

      timers.download-popular-videos = {
        description = "Schedule popular YouTube video downloads";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = popularVideosCfg.calendar;
          Persistent = true;
        };
      };
    };

    podmanServer.containers =
      lib.optionalAttrs popularVideosEnabled {
        bgutil-ytdlp-pot-provider = {
          quadlet.containerConfig = {
            image = "docker.io/brainicism/bgutil-ytdlp-pot-provider:latest";
            publishPorts = ["127.0.0.1:4416:4416"];
          };
        };
      }
      // {
        sonarr = {
          dependsOn = ["jackett"];
          quadlet.containerConfig = {
            image = "lscr.io/linuxserver/sonarr:latest";
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
            };
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${datasets.app.children.sonarr.path}:/config"
              "${datasets.media.children.tv.path}:/tv"
              "${datasets.downloads.path}:/downloads"
            ];
          };
        };

        radarr = {
          dependsOn = ["jackett"];
          quadlet.containerConfig = {
            image = "lscr.io/linuxserver/radarr:latest";
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
            };
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${datasets.app.children.radarr.path}:/config"
              "${datasets.media.children.movies.path}:/movies"
              "${datasets.downloads.path}:/downloads"
            ];
          };
        };

        bazarr = {
          quadlet.containerConfig = {
            image = "lscr.io/linuxserver/bazarr:latest";
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
            };
            volumes = [
              "${datasets.app.children.bazarr.path}:/config"
              "${datasets.media.children.tv.path}:/tv"
              "${datasets.media.children.movies.path}:/movies"
            ];
          };
        };

        maintainerr = {
          quadlet.containerConfig = {
            image = "ghcr.io/maintainerr/maintainerr:latest";
            user = containerUser;
            volumes = ["${datasets.app.children.maintainerr.path}:/opt/data"];
            environments = {
              BASE_PATH = "/maintainerr";
              DEBUG = "true";
              TZ = config.time.timeZone;
            };
          };
        };

        # pinchflat = {
        #   quadlet.containerConfig = {
        #     image = "ghcr.io/kieraneglin/pinchflat:latest";
        #     user = containerUser;
        #     environments = {
        #       BASE_ROUTE_PATH = "/pinchflat";
        #       TZ = config.time.timeZone;
        #     };
        #     volumes = [
        #       "${datasets.app.children.pinchflat.path}:/config"
        #       "${datasets.media.children.youtube.path}:/downloads"
        #     ];
        #     podmanArgs = [
        #       "--security-opt=label=disable"
        #       "--userns=keep-id"
        #     ];
        #   };
        # };
      };

    caddy.sites.media.endpoints = {
      maintainerr = {
        type = "proxy";
        auth = "oauth";
        path = "/maintainerr";
        host = "maintainerr";
        port = 6246;
        role = "admin";
      };
      # pinchflat = {
      #   type = "proxy";
      #   auth = "oauth";
      #   path = "/pinchflat";
      #   host = "pinchflat";
      #   port = 8945;
      #   role = "admin";
      #   handlePath = true;
      # };
      radarr = {
        type = "proxy";
        auth = "oauth";
        path = "/radarr";
        host = "radarr";
        port = 7878;
        role = "admin";
        spoofBasic = true;
      };
      sonarr = {
        type = "proxy";
        auth = "oauth";
        path = "/sonarr";
        host = "sonarr";
        port = 8989;
        role = "admin";
        spoofBasic = true;
      };
      bazarr = {
        type = "proxy";
        auth = "oauth";
        path = "/bazarr";
        host = "bazarr";
        port = 6767;
        role = "admin";
        spoofBasic = true;
      };
    };
  };
}
