{
  inputs,
  overlays,
  configurationBranch,
  configurationRevision,
  containerImages,
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable home-manager nix-flatpak disko disko-zfs agenix impermanence locus-vpn-client vscode-workspace-populator stylix catppuccin quadlet-nix nixos-apple-silicon tiny-dfr-nyan;
  inherit (nixpkgs) lib;
  accountNames = ["abovbel" "pbovbel" "rbovbel"];
  externalModules = [
    agenix.nixosModules.default
    nix-flatpak.nixosModules.nix-flatpak
    disko.nixosModules.disko
    disko-zfs.nixosModules.default
    impermanence.nixosModules.impermanence
    home-manager.nixosModules.home-manager
    stylix.nixosModules.stylix
    catppuccin.nixosModules.catppuccin
    quadlet-nix.nixosModules.quadlet
  ];
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
  validateHost = name: cfg: let
    configuredUserNames = map (user: user.name) cfg.users;
    unknownAccounts = lib.subtractLists accountNames configuredUserNames;
    invalidHideFromLogin = map (user: user.name) (builtins.filter (user: user ? hideFromLogin && !builtins.isBool user.hideFromLogin) cfg.users);
  in
    assert lib.assertMsg (builtins.match "age1.+" cfg.ageRecipient != null) "Host ${name} must define a valid ageRecipient";
    assert lib.assertMsg (builtins.elem cfg.installer ["generic" "apple-silicon"]) "Host ${name} must select a supported installer kind";
    assert lib.assertMsg (cfg.installer != "apple-silicon" || cfg.system == "aarch64-linux") "Host ${name}: apple-silicon installers require aarch64-linux";
    assert lib.assertMsg (builtins.isBool cfg.ciBuild) "Host ${name} must define ciBuild as a boolean";
    assert lib.assertMsg (unknownAccounts == []) "Host ${name} selects unknown accounts: ${lib.concatStringsSep ", " unknownAccounts}";
    assert lib.assertMsg (invalidHideFromLogin == []) "Host ${name} users must define hideFromLogin as a boolean: ${lib.concatStringsSep ", " invalidHideFromLogin}"; cfg;
  mkHostSettings = name: users: unstablePkgs: {config, ...}: let
    configuredUserNames = map (user: user.name) users;
    hiddenUserNames = map (user: user.name) (builtins.filter (user: user.hideFromLogin or false) users);
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
      sharedModules = [
        catppuccin.homeModules.catppuccin
      ];
      extraSpecialArgs = {inherit unstablePkgs vscode-workspace-populator containerImages;};
    };
  };
in
  name: rawCfg: extraModules: let
    cfg = validateHost name rawCfg;
    inherit (cfg) system;
    nixpkgsForHost =
      if cfg.useUnstablePackages or false
      then nixpkgs-unstable
      else nixpkgs;
    unstablePkgs = import nixpkgs-unstable {
      inherit system overlays;
      config.allowUnfree = true;
    };
  in
    nixpkgsForHost.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit agenix locus-vpn-client nixos-apple-silicon tiny-dfr-nyan unstablePkgs containerImages;
        inherit (inputs) asahi-vendor-firmware;
      };
      modules =
        [
          ./${name}/configuration.nix
          ../modules
          ../profiles/module.nix
          (mkHostSettings name cfg.users unstablePkgs)
        ]
        ++ externalModules
        ++ extraModules;
    }
