{
  config,
  lib,
  pkgs,
  ...
}: let
  switchTmpfilesUnit = "systemd-tmpfiles-resetup.service";
in {
  options.cockpit.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Cockpit web UI.";
  };

  config = lib.mkIf config.cockpit.enable {
    services.cockpit = {
      enable = true;
      openFirewall = false;
      allowed-origins = [
        "https://${config.networking.hostName}.${config.networking.domain}"
        "wss://${config.networking.hostName}.${config.networking.domain}"
        "https://${config.networking.hostName}.${config.tailscale.domain}"
        "wss://${config.networking.hostName}.${config.tailscale.domain}"
      ];
      plugins = [pkgs.cockpit-files pkgs.cockpit-podman];
      settings.WebService = {
        AllowUnencrypted = true;
        LoginTo = false;
        ProtocolHeader = "X-Forwarded-Proto";
        UrlRoot = "/cockpit";
      };
    };

    systemd.services.cockpit = {
      after = [switchTmpfilesUnit];
      serviceConfig.ExecStart = lib.mkForce [
        ""
        "${config.services.cockpit.package}/libexec/cockpit-tls --no-tls"
      ];
    };

    caddy.sites.media.endpoints.cockpit = {
      type = "proxy";
      auth = "oauth";
      path = "/cockpit";
      host = "host.containers.internal";
      port = 9090;
      role = "admin";
      spoofBasic = true;
    };

    networking.firewall.interfaces.${config.podmanServer.networkInterface}.allowedTCPPorts = [config.services.cockpit.port];
  };
}
