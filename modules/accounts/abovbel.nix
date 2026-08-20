{
  config,
  lib,
  ...
}: let
  cfg = config.accounts.abovbel;
  keys = import ../../keys.nix;
in {
  options.accounts.abovbel.enable = lib.mkEnableOption "the abovbel user account";

  config = lib.mkIf cfg.enable {
    age.secrets.abovbel-password-hash.file = ../../secrets/common/abovbel-password-hash.age;

    users.users.abovbel = {
      isNormalUser = true;
      hashedPasswordFile = config.age.secrets.abovbel-password-hash.path;
      description = "arthur@bovbel.com";
      extraGroups = ["networkmanager"];
      openssh.authorizedKeys.keys = [keys.pbovbel];
    };
  };
}
