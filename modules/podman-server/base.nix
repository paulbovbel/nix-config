{
  config,
  lanAddressCommand,
  lanNetworkCommand,
  lib,
  pkgs,
  ...
}: let
  cfg = config.podmanServer;
  active = cfg.containers != {};
  tailscaleNetwork = "100.64.0.0/10";
in {
  config = lib.mkMerge [
    {
      storage.datasets.app.autoSnapshot = {
        enable = true;
        frequent = false;
        hourly = true;
        daily = true;
        weekly = true;
        monthly = false;
      };
    }

    (lib.mkIf active {
      users = {
        users.${cfg.user.name} = {
          inherit (cfg.user) uid group;
        };
        groups.${cfg.user.group}.gid = cfg.user.gid;
      };

      podmanServer.derivedEnvFiles.lan = {
        wants = ["network-online.target"];
        after = ["network-online.target"];
        packages = [pkgs.gawk pkgs.iproute2];
        mode = "0644";
        variables = {
          LAN_ADDRESS = "$(${lanAddressCommand})";
          LAN_NETWORK = "$(${lanNetworkCommand})";
          TAILSCALE_NETWORK = tailscaleNetwork;
        };
      };

      systemd = {
        tmpfiles.rules = [
          "d /run/podman-server 0755 root root - -"
        ];
      };

      rootZfs.persistDirectories = [
        "/var/lib/podman-server"
        "/var/lib/containers"
      ];
    })
  ];
}
