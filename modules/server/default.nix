{config, ...}: {
  imports = [
    ../common
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
    extraUpFlags = [
      "--advertise-tags=tag:server"
      "--advertise-exit-node"
    ];
  };

  # impermanenceRoot.persistDirectories = [
  #   "/var/lib/tailscale"
  # ];
}
