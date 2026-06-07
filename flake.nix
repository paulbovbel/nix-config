{
  description = "pbovbel NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    locus-vpn-client = {
      url = "git+ssh://git@github.com/locusrobotics/locus-vpn-client.git?ref=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    vscode-workspace-populator = {
      url = "git+ssh://git@github.com/locusrobotics/vscode-workspace-populator.git?ref=refs/tags/v0.0.1";
      flake = false;
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-master,
    home-manager,
    nix-flatpak,
    disko,
    agenix,
    impermanence,
    locus-vpn-client,
    nix-vscode-extensions,
    vscode-workspace-populator,
    ...
  }: let
    inherit (nixpkgs) lib;
    system = "x86_64-linux";
    overlays = [nix-vscode-extensions.overlays.default];

    mkPkgs = src:
      import src {
        inherit system overlays;
        config.allowUnfree = true;
      };

    systemProfiles = {
      common = ./modules/common;
      graphical = ./modules/graphical;
      work = ./modules/work;
      gaming = ./modules/gaming;
      nvidia = ./modules/nvidia;
      headless = ./modules/headless;
      llama-cpp = ./modules/llama-cpp;
      impermanence-root = ./modules/impermanence-root;
    };

    userProfiles = import ./users;

    userHomeModules = user: let
      profiles = userProfiles.${user.name};
    in
      map (profileName: profiles.${profileName}.module) user.profiles;

    userSystemProfileNames = user: let
      profiles = userProfiles.${user.name};
    in
      lib.unique (map (profileName: profiles.${profileName}.systemProfile) user.profiles);

    mkHost = name: cfg: let
      nixpkgsForHost =
        if cfg.useUnstablePackages or false
        then nixpkgs-unstable
        else nixpkgs;
      unstablePkgs = mkPkgs nixpkgs-unstable;
      masterPkgs = mkPkgs nixpkgs-master;
    in
      nixpkgsForHost.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit agenix locus-vpn-client unstablePkgs masterPkgs;
        };
        modules =
          [
            ./hosts/${name}/configuration.nix
            # Declare custom option schemas globally so hosts can set options
            # even when the corresponding profile module is not imported.
            ./modules/impermanence-root/options.nix
            ./modules/nvidia/options.nix
            agenix.nixosModules.default
            nix-flatpak.nixosModules.nix-flatpak
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                backupFileExtension = "backup";
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit unstablePkgs;
                  inherit masterPkgs;
                  inherit vscode-workspace-populator;
                };
              };
            }
          ]
          # System profiles are the union of host-selected profiles and
          # transitive profiles implied by each user's chosen HM profile.
          ++ map (profile: systemProfiles.${profile}) (lib.unique ((cfg.systemProfiles or []) ++ lib.flatten (map userSystemProfileNames cfg.users)))
          ++ map (user: user.systemModule) cfg.users
          ++ map (user: {
            home-manager.users.${user.name} = {
              imports = userHomeModules user;
            };
          })
          cfg.users;
      };

    hosts = import ./hosts;
  in {
    nixosConfigurations = lib.mapAttrs mkHost hosts;
  };
}
