registry: let
  accountNames = builtins.attrNames (import ../modules/accounts/registry.nix);
  require = condition: message: value:
    if condition
    then value
    else throw message;
  visit = path: name:
    require (!(builtins.elem name path)) "Profile inheritance cycle: ${builtins.concatStringsSep " -> " (path ++ [name])}"
    (require (builtins.hasAttr name registry) "Unknown inherited profile ${name} in: ${builtins.concatStringsSep " -> " (path ++ [name])}"
      (builtins.deepSeq (map (visit (path ++ [name])) registry.${name}.extends) true));
  validate = name: profile: let
    unknownAccounts = builtins.filter (user: !builtins.elem user accountNames) (builtins.attrNames profile.homeModule);
  in
    require (unknownAccounts == []) "Profile ${name} supports unknown accounts: ${builtins.concatStringsSep ", " unknownAccounts}"
    (builtins.seq (visit [] name) profile);
  validated = builtins.mapAttrs validate registry;
in
  builtins.deepSeq validated validated
