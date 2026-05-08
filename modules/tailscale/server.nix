{ ... }:

{
  imports = [
    ./default.nix
  ];

  age.secrets.tailscale-oauth-authkey = {
    file = ../../secrets/server/tailscale-oauth-authkey.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.tailscale.extraUpFlags = [
    "--advertise-tags=tag:server",
    "--advertise-exit-node",
    "--reset"
  ];
}
