{ ... }:

{
  imports = [
    ./default.nix
  ];

  age.secrets.tailscale-oauth-authkey = {
    file = ../../secrets/laptop/tailscale-oauth-authkey.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.tailscale.extraUpFlags = [
    "--advertise-tags=tag:laptop"
    "--accept-routes=false"
  ];
}
