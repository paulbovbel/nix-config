{lib, ...}: let
  registry = import ./default.nix;
  users = lib.unique (lib.concatMap (profile: lib.attrNames profile.homeModule) (lib.attrValues registry));
in {
  options = {
    userProfiles = lib.mkOption {
      default = {};
      description = "Profiles selected for each local user; system behavior applies to the whole host.";
      type = lib.types.submodule {
        options = lib.genAttrs users (user:
          lib.mkOption {
            type = lib.types.listOf (lib.types.enum (lib.attrNames (lib.filterAttrs (_: profile: profile.homeModule ? ${user}) registry)));
            default = [];
            description = "Profiles selected for ${user}. Inherited system profiles are enabled automatically.";
          });
      };
    };
    systemProfiles = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.listOf (lib.types.enum (lib.attrNames registry));
      description = "Effective system profiles, including inherited profiles.";
    };
  };
}
