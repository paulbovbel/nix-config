{
  inputs,
  overlays,
  configurationBranch,
  configurationRevision,
  containerImages,
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable home-manager nix-flatpak disko disko-zfs agenix impermanence locus-vpn-client stylix catppuccin quadlet-nix nixos-apple-silicon tiny-dfr-nyan rookie-cli;
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
in
  name: cfg: extraModules: let
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
        inherit agenix locus-vpn-client nixos-apple-silicon tiny-dfr-nyan rookie-cli unstablePkgs containerImages;
        inherit (inputs) jellyfin-plugin-sso asahi-vendor-firmware;
      };
      modules =
        [
          ./${name}/configuration.nix
          ../modules
          ../profiles/module.nix
          (import ./common.nix {
            inherit overlays configurationBranch configurationRevision containerImages name unstablePkgs;
            inherit (inputs) catppuccin vscode-workspace-populator;
            inherit (cfg) users;
          })
        ]
        ++ externalModules
        ++ extraModules;
    }
