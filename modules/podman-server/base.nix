{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.podmanServer;
  active = cfg.containers != {};
  tailscaleNetwork = "100.64.0.0/10";
  lanInterfaceCommand = "ip -o -4 route show to default | awk '{print $5; exit}'";
  lanAddressCommand = "iface=$(${lanInterfaceCommand}); ip -o -4 addr show dev \"$iface\" scope global | awk '{split($4, a, \"/\"); print a[1]; exit}'";
  lanNetworkCommand = "iface=$(${lanInterfaceCommand}); ip -o -4 route show dev \"$iface\" proto kernel scope link | awk '{print $1; exit}'";
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

      impermanenceRoot.persistDirectories = [
        "/var/lib/podman-server"
        "/var/lib/containers"
      ];
    })
  ];
}
