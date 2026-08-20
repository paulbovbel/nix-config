{
  config,
  lib,
  ...
}: let
  cfg = config.accounts.rbovbel;
  keys = import ../../keys.nix;
in {
  options.accounts.rbovbel.enable = lib.mkEnableOption "the rbovbel user account";

  config = lib.mkIf cfg.enable {
    age.secrets.rbovbel-password-hash.file = ../../secrets/common/rbovbel-password-hash.age;

    users.users.rbovbel = {
      isNormalUser = true;
      hashedPasswordFile = config.age.secrets.rbovbel-password-hash.path;
      description = "rebecca@bovbel.com";
      extraGroups = ["networkmanager"];
      openssh.authorizedKeys.keys = [keys.pbovbel];
    };
  };
}
