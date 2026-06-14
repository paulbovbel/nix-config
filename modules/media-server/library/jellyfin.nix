{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
in {
  config = lib.mkIf (cfg.enable && cfg.components.library.enable) {
    storage.datasets.app.children.jellyfin = {};

    podmanServer.containers.jellyfin = {
      image = "lscr.io/linuxserver/jellyfin:latest";
      environment = {
        PUID = user.uid;
        PGID = user.gid;
        TZ = config.time.timeZone;
      };
      volumes = [
        "${datasets.app.children.jellyfin.path}:/config"
        "${datasets.media.path}:/data:ro"
      ];
      devices = ["/dev/dri:/dev/dri"];
      requiresMountsFor = ["/storage"];
    };

    caddy.endpoints.jellyfin = {
      type = "proxy";
      auth = null;
      path = "/jellyfin";
      host = "jellyfin";
      port = 8096;
    };
  };
}
