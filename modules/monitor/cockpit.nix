{
  config,
  lib,
  pkgs,
  ...
}: {
  options.cockpit.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Cockpit web UI.";
  };

  config = lib.mkIf config.cockpit.enable {
    services.cockpit = {
      enable = true;
      openFirewall = false;
      plugins = [pkgs.cockpit-zfs];
      settings.WebService = {
        AllowUnencrypted = true;
        LoginTo = false;
      };
    };

    caddy.endpoints.cockpit = {
      type = "proxy";
      auth = "oauth";
      path = "/cockpit";
      host = "host.containers.internal";
      port = 9090;
      role = "admin";
      spoofBasic = true;
    };
  };
}
