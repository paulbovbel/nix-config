{config, ...}: let
  inherit (config.podmanServer) user;
in {
  imports = [
    ../common/system.nix
  ];

  age.secrets.tailscale-oauth-authkey = {
    file = ../../secrets/server/tailscale-oauth-authkey.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-oauth-authkey.path;
    authKeyParameters.ephemeral = false;
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--advertise-tags=tag:headless"
      "--advertise-exit-node"
    ];
  };

  systemd.services.tailscaled-autoconnect = {
    description = "Authenticate Tailscale after network and DNS are online";
    wants = ["network-online.target" "systemd-resolved.service"];
    after = ["network-online.target" "systemd-resolved.service"];
  };

  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_PERMIT_CERT_UID=${toString user.uid}"
  ];

  rootFs.persistDirectories = [
    "/var/lib/tailscale"
  ];
}
