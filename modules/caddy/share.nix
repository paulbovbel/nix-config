{
  config,
  lib,
  ...
}: let
  datasets = config.storage.datasets;
in {
  config = lib.mkIf (config.caddy.enable && config.caddy.components.share.enable) {
    storage.datasets.app.children.filebrowser = {};

    podmanServer = {
      containers = {
        caddy.volumes = ["${datasets.media.path}:/share:ro"];

        filebrowser = {
          image = "filebrowser/filebrowser";
          volumes = [
            "${datasets.media.path}:/srv"
            "${datasets.app.children.filebrowser.path}/filebrowser.db:/database.db"
          ];
          command = "-b /browser";
        };
      };
    };

    caddy.endpoints = {
      share = {
        type = "share";
        auth = "oauth";
        path = "/share";
        role = "share";
      };

      browser = {
        type = "proxy";
        auth = "oauth";
        path = "/browser";
        host = "filebrowser";
        port = 80;
        role = "admin";
      };
    };
  };
}
