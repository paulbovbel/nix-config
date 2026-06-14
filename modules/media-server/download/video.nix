{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
in {
  config = lib.mkIf (cfg.enable && cfg.components.downloads.enable) {
    storage.datasets.app.children = {
      bazarr = {};
      maintainerr = {};
      radarr = {};
      sonarr = {};
    };

    podmanServer.containers = {
      sonarr = {
        image = "lscr.io/linuxserver/sonarr:latest";
        dependsOn = ["jackett"];
        environment = {
          PUID = user.uid;
          PGID = user.gid;
          TZ = config.time.timeZone;
        };
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "${datasets.app.children.sonarr.path}:/config"
          "${datasets.media.children.tv.path}:/tv"
          "${datasets.downloads.path}:/downloads"
        ];
        requiresMountsFor = ["/storage"];
      };

      radarr = {
        image = "lscr.io/linuxserver/radarr";
        dependsOn = ["jackett"];
        environment = {
          PUID = user.uid;
          PGID = user.gid;
          TZ = config.time.timeZone;
        };
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "${datasets.app.children.radarr.path}:/config"
          "${datasets.media.children.movies.path}:/movies"
          "${datasets.downloads.path}:/downloads"
        ];
        requiresMountsFor = ["/storage"];
      };

      bazarr = {
        image = "lscr.io/linuxserver/bazarr";
        environment = {
          PUID = user.uid;
          PGID = user.gid;
          TZ = config.time.timeZone;
        };
        volumes = [
          "${datasets.app.children.bazarr.path}:/config"
          "${datasets.media.children.tv.path}:/tv"
          "${datasets.media.children.movies.path}:/movies"
        ];
        requiresMountsFor = ["/storage"];
      };

      maintainerr = {
        image = "ghcr.io/maintainerr/maintainerr:latest";
        volumes = ["${datasets.app.children.maintainerr.path}:/opt/data"];
        environment = {
          BASE_PATH = "/maintainerr";
          DEBUG = "true";
          TZ = config.time.timeZone;
        };
        requiresMountsFor = ["/storage"];
      };
    };

    caddy.endpoints = {
      maintainerr = {
        type = "proxy";
        auth = "oauth";
        path = "/maintainerr";
        host = "maintainerr";
        port = 6246;
        role = "admin";
      };
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
