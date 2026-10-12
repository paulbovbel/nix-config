hosts: let
  accountNames = builtins.attrNames (import ../modules/accounts/registry.nix);
  validate = name: cfg: let
    userNames = map (user: user.name) cfg.users;
    unknownAccounts = builtins.filter (user: !builtins.elem user accountNames) userNames;
    duplicateAccounts = builtins.filter (user: builtins.length (builtins.filter (other: other == user) userNames) > 1) userNames;
    invalidHideFromLogin = map (user: user.name) (builtins.filter (user: user ? hideFromLogin && !builtins.isBool user.hideFromLogin) cfg.users);
    checks = [
      {
        condition = builtins.match "age1.+" cfg.ageRecipient != null;
        message = "Host ${name} must define a valid ageRecipient";
      }
      {
        condition = builtins.elem cfg.installer ["generic" "apple-silicon"];
        message = "Host ${name} must select a supported installer kind";
      }
      {
        condition = cfg.installer != "apple-silicon" || cfg.system == "aarch64-linux";
        message = "Host ${name}: apple-silicon installers require aarch64-linux";
      }
      {
        condition = builtins.isBool cfg.ciBuild;
        message = "Host ${name} must define ciBuild as a boolean";
      }
      {
        condition = builtins.isBool (cfg.useUnstablePackages or false);
        message = "Host ${name} must define useUnstablePackages as a boolean";
      }
      {
        condition = unknownAccounts == [];
        message = "Host ${name} selects unknown accounts: ${builtins.concatStringsSep ", " unknownAccounts}";
      }
      {
        condition = duplicateAccounts == [];
        message = "Host ${name} selects duplicate accounts: ${builtins.concatStringsSep ", " duplicateAccounts}";
      }
      {
        condition = invalidHideFromLogin == [];
        message = "Host ${name} users must define hideFromLogin as a boolean: ${builtins.concatStringsSep ", " invalidHideFromLogin}";
      }
    ];
    passed = builtins.all (check:
      if check.condition
      then true
      else throw check.message)
    checks;
  in
    builtins.seq passed cfg;
  validated = builtins.mapAttrs validate hosts;
in
  builtins.deepSeq validated validated
