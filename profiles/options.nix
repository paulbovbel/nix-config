{lib, ...}: let
  registry = import ./default.nix;
  users = lib.unique (lib.concatMap (profile: lib.attrNames profile.homeModule) (lib.attrValues registry));
in {
  options = {
    maintenance.passwordlessSudo = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Temporarily let `wheel` members run `sudo` without a password, for interactive debugging over SSH where no terminal can prompt. Every rebuild warns while it is set, because it removes the local confirmation step for root access. Leave it `false` in committed configuration and revert it once the maintenance window ends.";
    };
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
