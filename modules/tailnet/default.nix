{
  config,
  lib,
  ...
}: let
  selectedUsers = lib.attrNames (lib.filterAttrs (_: profiles: profiles != []) config.userProfiles);
  hasKids = builtins.any (user: config.accounts.${user}.isKid) selectedUsers;
  hasAdults = builtins.any (user: !config.accounts.${user}.isKid) selectedUsers;
in {
  imports = [./options.nix];
  config = lib.mkMerge [
    {
      moduleDocumentation.tailnet = {
        title = "Tailnet";
        category = "Networking";
        summary = "Tailscale enrollment, device identity tags, and generated access policy.";
      };
      tailnet.tags = lib.mkDefault (
        if hasKids
        then ["tag:kids-device"]
        else lib.optional hasAdults "tag:adult-device"
      );
      assertions = [
        {
          assertion = !(builtins.elem "tag:adult-device" config.tailnet.tags && builtins.elem "tag:kids-device" config.tailnet.tags);
          message = "Adult and kids tailnet identities must be mutually exclusive; Tailscale grants are additive.";
        }
      ];
    }
    (lib.mkIf config.tailnet.enable {
      age.secrets.tailscale-oauth-authkey = {
        file = ../../secrets/common/tailscale-oauth-authkey.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      services.tailscale = {
        enable = true;
        authKeyFile = config.age.secrets.tailscale-oauth-authkey.path;
        authKeyParameters.ephemeral = false;
        extraUpFlags = [
          "--advertise-tags=${lib.concatStringsSep "," config.tailnet.tags}"
          "--hostname=${config.networking.hostName}"
        ];
      };
      rootFs.persistDirectories = ["/var/lib/tailscale"];
    })
  ];
}
