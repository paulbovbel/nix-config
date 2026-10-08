{
  config,
  lib,
  ...
}: let
  registry = import ./default.nix;
  selections = lib.filterAttrs (_: selected: selected != []) config.userProfiles;
  selected = lib.unique (lib.concatLists (lib.attrValues selections));
  resolveProfiles = names:
    map (item: item.key) (builtins.genericClosure {
      startSet = map (key: {inherit key;}) names;
      operator = item: map (key: {inherit key;}) registry.${item.key}.extends;
    });
in {
  imports = [./options.nix ./common/system.nix] ++ map (profile: profile.systemModule) (lib.attrValues registry);

  config = {
    systemProfiles = resolveProfiles selected;
    assertions =
      lib.mapAttrsToList (user: _: {
        assertion = config.accounts.${user}.enable;
        message = "userProfiles.${user} requires accounts.${user}.enable.";
      })
      selections;
    home-manager.users =
      lib.mapAttrs (user: selectedProfiles: {
        # These imports belong to the nested Home Manager evaluation, not the
        # NixOS import graph, so they may depend on NixOS profile selections.
        imports = [./selected.nix] ++ map (name: registry.${name}.homeModule.${user}) selectedProfiles;
        profiles.selected = resolveProfiles selectedProfiles;
      })
      selections;
  };
}
