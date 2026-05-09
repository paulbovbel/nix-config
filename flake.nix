{
  description = "pbovbel NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix.url = "github:ryantm/agenix";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nix-flatpak, agenix, nix-vscode-extensions, ... }:
    let
      lib = nixpkgs.lib;

      systemProfiles = {
        common = ./modules/common;
        graphical = ./modules/graphical;
        work = ./modules/work;
        gaming = ./modules/gaming;
        server = ./modules/server;
      };

      userProfiles = {
        pbovbel = {
          headless = {
            module = ./users/pbovbel/home/profiles/headless.nix;
            systemProfile = "server";
          };
          graphical = {
            module = ./users/pbovbel/home/profiles/graphical.nix;
            systemProfile = "graphical";
          };
          work = {
            module = ./users/pbovbel/home/profiles/work.nix;
            systemProfile = "work";
          };
          gaming = {
            module = ./users/pbovbel/home/profiles/gaming.nix;
            systemProfile = "gaming";
          };
        };

        rbovbel = {
          graphical = {
            module = ./users/rbovbel/home/profiles/graphical.nix;
            systemProfile = "graphical";
          };
        };
      };

      userHomeModules = user:
        let
          profiles = userProfiles.${user.name};
        in
        map (profileName: profiles.${profileName}.module) user.profiles;

      userSystemProfileNames = user:
        let
          profiles = userProfiles.${user.name};
        in
        lib.unique (map (profileName: profiles.${profileName}.systemProfile) user.profiles);

      mkHost = name: cfg:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = let
            unstablePkgs = import nixpkgs-unstable {
              system = "x86_64-linux";
              config.allowUnfree = true;
              overlays = [ nix-vscode-extensions.overlays.default ];
            };
          in {
            inherit unstablePkgs;
            vscodeMarketplaceExtensions = unstablePkgs.vscode-marketplace;
          };
          modules =
            [
              cfg.hostModule
              agenix.nixosModules.default
              nix-flatpak.nixosModules.nix-flatpak
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
              }
            ]
            ++ map (profile: systemProfiles.${profile}) (lib.unique ((cfg.systemProfiles or [ ]) ++ lib.flatten (map userSystemProfileNames cfg.users)))
            ++ map (user: user.systemModule) cfg.users
            ++ map (user: {
              home-manager.users.${user.name} = {
                imports = userHomeModules user;
              };
            }) cfg.users;
        };

      hosts = {
        white-tower = {
          hostModule = ./hosts/white-tower/configuration.nix;
          users = [
            {
              name = "pbovbel";
              systemModule = ./users/pbovbel.nix;
              profiles = [ "gaming" ];
            }
            {
              name = "rbovbel";
              systemModule = ./users/rbovbel.nix;
              profiles = [ "graphical" ];
            }
          ];
        };

        pbovbel-dell = {
          hostModule = ./hosts/pbovbel-dell/configuration.nix;
          users = [
            {
              name = "pbovbel";
              systemModule = ./users/pbovbel.nix;
              profiles = [ "work" ];
            }
          ];
        };

        media = {
          hostModule = ./hosts/media/configuration.nix;
          systemProfiles = [ "server" ];
          users = [
            {
              name = "pbovbel";
              systemModule = ./users/pbovbel.nix;
              profiles = [ "headless" ];
            }
          ];
        };
      };
    in {
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;
    };
}
