{
  config,
  lib,
  ...
}: let
  inherit (config.podmanServer) user;
in {
  config = lib.mkIf (builtins.elem "headless" config.systemProfiles) {
    services.tailscale.useRoutingFeatures = "server";

    systemd.services.tailscaled-autoconnect = {
      description = "Authenticate Tailscale after network and DNS are online";
      wants = ["network-online.target" "systemd-resolved.service"];
      after = ["network-online.target" "systemd-resolved.service"];
    };

    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_PERMIT_CERT_UID=${toString user.uid}"
    ];
  };
}
