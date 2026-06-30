{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
in {
  config = lib.mkIf cfg.library.enable {
    storage.datasets.app.children.jellyfin = {};

    podmanServer.containers.jellyfin = {
      quadlet.containerConfig = {
        image = "lscr.io/linuxserver/jellyfin:latest";
        publishPorts = ["8096:8096"];
        environments = {
          PUID = toString user.uid;
          PGID = toString user.gid;
          TZ = config.time.timeZone;
        };
        volumes = [
          "${datasets.app.children.jellyfin.path}:/config"
          "${datasets.media.path}:/data:ro"
        ];
        devices = ["/dev/dri:/dev/dri"];
      };
    };

    caddy.sites.media.endpoints.jellyfin = {
      type = "proxy";
      auth = null;
      path = "/jellyfin";
      host = "jellyfin";
      port = 8096;
    };
  };
}
