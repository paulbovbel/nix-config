{
  description = "pbovbel NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    agenix.url = "github:ryantm/agenix";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
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
    nix-vscode-extensions,
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
      server = ./modules/server;
      llama-cpp = ./modules/llama-cpp;
      impermanence-root = ./modules/impermanence-root;
    };

    userProfiles = {
      pbovbel = {
        headless = {
          module = ./users/pbovbel/headless.nix;
          systemProfile = "server";
        };
        graphical = {
          module = ./users/pbovbel/graphical.nix;
          systemProfile = "graphical";
        };
        work = {
          module = ./users/pbovbel/work.nix;
          systemProfile = "work";
        };
        gaming = {
          module = ./users/pbovbel/gaming.nix;
          systemProfile = "gaming";
        };
      };

      rbovbel = {
        graphical = {
          module = ./users/rbovbel/graphical.nix;
          systemProfile = "graphical";
        };
      };
    };

    userHomeModules = user: let
      profiles = userProfiles.${user.name};
    in
      map (profileName: profiles.${profileName}.module) user.profiles;

    userSystemProfileNames = user: let
      profiles = userProfiles.${user.name};
    in
      lib.unique (map (profileName: profiles.${profileName}.systemProfile) user.profiles);

    mkHost = name: cfg: let
      unstablePkgs = mkPkgs nixpkgs-unstable;
      masterPkgs = mkPkgs nixpkgs-master;
    in
      lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit unstablePkgs;
          inherit masterPkgs;
        };
        modules =
          [
            ./hosts/${name}/configuration.nix
            # Declare custom option schemas globally so hosts can set options
            # even when the corresponding profile module is not imported.
            ./modules/impermanence-root/options.nix
            agenix.nixosModules.default
            nix-flatpak.nixosModules.nix-flatpak
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {inherit unstablePkgs;};
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
