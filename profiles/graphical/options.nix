{
  config,
  lib,
  ...
}: let
  registry = import ../default.nix;
  isGraphical = name: name == "graphical" || lib.any isGraphical registry.${name}.extends;
  graphicalUsers = lib.filterAttrs (_: user: lib.any isGraphical user.profiles) config.userProfiles;
in {
  options.graphical = {
    resolvedUserShells = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.attrsOf (lib.types.enum ["gnome" "hyprland"]);
      description = "Effective shell for each graphical user.";
    };
  };

  config = {
    graphical.resolvedUserShells = lib.mapAttrs (_: user: user.shell) graphicalUsers;
    assertions =
      lib.mapAttrsToList (user: selection: {
        assertion = selection.shell != "hyprland" || builtins.hasAttr user graphicalUsers;
        message = "userProfiles.${user}.shell = hyprland requires a selected graphical, work, or gaming profile.";
      })
      config.userProfiles;
  };
}
