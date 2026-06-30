{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  containerUser = "${toString user.uid}:${toString user.gid}";
in {
  config = lib.mkIf cfg.downloads.enable {
    storage.datasets.app.children = {
      bazarr = {};
      maintainerr = {};
      radarr = {};
      sonarr = {};
    };

    podmanServer.containers = {
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
