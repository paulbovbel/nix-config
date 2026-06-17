{
  config,
  lib,
  pkgs,
  tailscaleDomain,
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
      allowed-origins = [
        "https://${config.ddns.record}"
        "wss://${config.ddns.record}"
        "https://${config.networking.hostName}.${tailscaleDomain}"
        "wss://${config.networking.hostName}.${tailscaleDomain}"
      ];
      plugins = [pkgs.cockpit-files pkgs.cockpit-podman];
      settings.WebService = {
        AllowUnencrypted = true;
        LoginTo = false;
        ProtocolHeader = "X-Forwarded-Proto";
        UrlRoot = "/cockpit";
      };
    };

    systemd.services.cockpit.serviceConfig.ExecStart = lib.mkForce [
      ""
      "${config.services.cockpit.package}/libexec/cockpit-tls --no-tls"
    ];

    caddy.endpoints.cockpit = {
      type = "proxy";
      auth = "oauth";
      path = "/cockpit";
      host = "host.containers.internal";
      port = 9090;
      role = "admin";
      spoofBasic = true;
    };

    networking.firewall.interfaces.podman1.allowedTCPPorts = [config.services.cockpit.port];
  };
}
