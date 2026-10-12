{
  inputs,
  overlays,
  configurationBranch,
  configurationRevision,
  containerImages,
  name,
  users,
  unstablePkgs,
}: {
  config,
  lib,
  ...
}: let
  inherit (inputs) catppuccin vscode-workspace-populator;
  configuredUserNames = map (user: user.name) users;
  hiddenUserNames = map (user: user.name) (builtins.filter (user: user.hideFromLogin or false) users);
  catppuccinPaletteSource = let
    source = (lib.importJSON "${catppuccin}/pkgs/sources.json").palette;
  in
    (builtins.fetchTree {
      type = "github";
      owner = "catppuccin";
      repo = "palette";
      inherit (source) rev;
      narHash = source.hash;
    }).outPath;
in {
  assertions = [
    {
      assertion = config.networking.hostName == name;
      message = "Host ${name} configures networking.hostName as ${config.networking.hostName}";
    }
  ];
  rootFs.homeUsers = configuredUserNames;
  system.configurationRevision = configurationRevision;
  environment.etc."nix-config/branch".text = configurationBranch;
  accounts = lib.genAttrs configuredUserNames (_: {enable = true;});
  services.displayManager.gdm.settings = lib.mkIf (hiddenUserNames != []) {
    greeter.Exclude = lib.concatStringsSep "," hiddenUserNames;
  };
  # Avoid building a target-platform package for TTY colors during evaluation.
  catppuccin.sources.palette = catppuccinPaletteSource;
  nixpkgs = {
    inherit overlays;
    config.allowUnfree = true;
  };
  home-manager = {
    backupFileExtension = "backup";
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [catppuccin.homeModules.catppuccin];
    extraSpecialArgs = {inherit unstablePkgs vscode-workspace-populator containerImages;};
  };
}
