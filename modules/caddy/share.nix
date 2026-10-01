{
  config,
  lib,
  ...
}: let
  datasets = config.storage.datasets;
in {
  config = lib.mkIf (config.caddy.enable && config.caddy.share.enable) {
    storage.datasets = {
      media = {};
    };

    podmanServer = {
      containers = {
        caddy.quadlet.containerConfig.volumes = ["${datasets.media.path}:/share:ro"];
      };
    };

    caddy.sites.media.endpoints = {
      share = {
        dashboard = {
          name = "Shared files";
          iconName = "folder";
        };
        type = "share";
        auth = "oauth";
        path = "/share";
        role = "user";
      };
    };
  };
}
