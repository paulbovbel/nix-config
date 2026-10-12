{
  config,
  lib,
  pkgs,
  ...
}: let
  lan = import ../../lib/lan-commands.nix;
  cfg = config.podmanServer;
  active = cfg.containers != {};
  tailscaleNetwork = "100.64.0.0/10";
in {
  config = lib.mkIf active {
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
        LAN_ADDRESS = "$(${lan.address})";
        LAN_NETWORK = "$(${lan.network})";
        TAILSCALE_NETWORK = tailscaleNetwork;
      };
    };

    systemd.tmpfiles.rules = [
      "d /run/podman-server 0755 root root - -"
    ];

    rootFs.persistDirectories = [
      "/var/lib/podman-server"
      "/var/lib/containers"
    ];
  };
}
