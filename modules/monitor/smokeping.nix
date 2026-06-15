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
    default = true;
    description = "Enable Smokeping container and Caddy endpoint.";
  };

  config = lib.mkIf (config.cockpit.enable && config.smokeping.enable) {
    storage.datasets.app.children.smokeping = {};

    podmanServer = {
      containers.smokeping = {
        image = "lscr.io/linuxserver/smokeping:latest";
        environment = {
          PUID = user.uid;
          PGID = user.gid;
          TZ = config.time.timeZone;
        };
        volumes = [
          "${datasets.app.children.smokeping.path}/config:/config"
          "${datasets.app.children.smokeping.path}/data:/data"
        ];
      };
    };

    caddy.endpoints.smokeping = {
      type = "proxy";
      auth = "oauth";
      path = "/smokeping";
      host = "smokeping";
      port = 80;
      role = "admin";
    };
  };
}
