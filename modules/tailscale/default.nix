{ lib, config, ... }:

{
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;

  services.tailscale.authKeyFile = lib.mkIf (config.age.secrets ? tailscale-oauth-authkey)
    config.age.secrets.tailscale-oauth-authkey.path;
}
