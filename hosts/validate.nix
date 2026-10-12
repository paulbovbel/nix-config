hosts: let
  accountNames = builtins.attrNames (import ../modules/accounts/registry.nix);
  require = condition: message: value:
    if condition
    then value
    else throw message;
  validate = name: cfg: let
    userNames = map (user: user.name) cfg.users;
    unknownAccounts = builtins.filter (user: !builtins.elem user accountNames) userNames;
    duplicateAccounts = builtins.filter (user: builtins.length (builtins.filter (other: other == user) userNames) > 1) userNames;
    invalidHideFromLogin = map (user: user.name) (builtins.filter (user: user ? hideFromLogin && !builtins.isBool user.hideFromLogin) cfg.users);
  in
    require (builtins.match "age1.+" cfg.ageRecipient != null) "Host ${name} must define a valid ageRecipient"
    (require (builtins.elem cfg.installer ["generic" "apple-silicon"]) "Host ${name} must select a supported installer kind"
      (require (cfg.installer != "apple-silicon" || cfg.system == "aarch64-linux") "Host ${name}: apple-silicon installers require aarch64-linux"
        (require (builtins.isBool cfg.ciBuild) "Host ${name} must define ciBuild as a boolean"
          (require (builtins.isBool (cfg.useUnstablePackages or false)) "Host ${name} must define useUnstablePackages as a boolean"
            (require (unknownAccounts == []) "Host ${name} selects unknown accounts: ${builtins.concatStringsSep ", " unknownAccounts}"
              (require (duplicateAccounts == []) "Host ${name} selects duplicate accounts: ${builtins.concatStringsSep ", " duplicateAccounts}"
                (require (invalidHideFromLogin == []) "Host ${name} users must define hideFromLogin as a boolean: ${builtins.concatStringsSep ", " invalidHideFromLogin}" cfg)))))));
  validated = builtins.mapAttrs validate hosts;
in
  builtins.deepSeq validated validated
