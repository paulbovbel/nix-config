{
  config,
  lib,
  ...
}: let
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
in {
  options.smokeping.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Smokeping container and Caddy endpoint.";
  };

  config = lib.mkIf config.smokeping.enable {
    storage.datasets.app.children.smokeping = {};

    podmanServer = {
      containers.smokeping = {
        quadlet.containerConfig = {
          image = "lscr.io/linuxserver/smokeping:latest";
          environments = {
            PUID = toString user.uid;
            PGID = toString user.gid;
            TZ = config.time.timeZone;
          };
          volumes = [
            "${datasets.app.children.smokeping.path}/config:/config"
            "${datasets.app.children.smokeping.path}/data:/data"
          ];
        };
      };
    };

    caddy.sites.media.endpoints.smokeping = {
      type = "proxy";
      auth = "oauth";
      path = "/smokeping";
      host = "smokeping";
      port = 80;
      role = "admin";
    };
  };
}
