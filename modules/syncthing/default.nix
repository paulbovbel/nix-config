{
  config,
  lib,
  ...
}: let
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
in {
  imports = [./options.nix];

  config = lib.mkIf config.syncthing.enable {
    storage.datasets = {
      backup.autoSnapshot = {
        enable = true;
        frequent = false;
        hourly = false;
        daily = true;
        weekly = true;
        monthly = false;
      };

      app.children.syncthing = {};
    };

    services.syncthing = {
      enable = true;
      inherit (user) group;
      user = user.name;
      dataDir = "/storage";
      configDir = datasets.app.children.syncthing.path;
      guiAddress = "0.0.0.0:8384";
      openDefaultPorts = true;
    };

    systemd.services.syncthing.unitConfig.RequiresMountsFor = ["/storage"];

    caddy.endpoints.syncthing = lib.mkIf config.syncthing.caddy.enable {
      type = "proxy";
      auth = "oauth";
      path = "/syncthing";
      host = "host.containers.internal";
      port = 8384;
      role = "admin";
      stripPrefix = true;
    };
  };
}
