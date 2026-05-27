{
  description = "pbovbel NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    agenix.url = "github:ryantm/agenix";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-master, home-manager, nix-flatpak, agenix, nix-vscode-extensions, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      overlays = [ nix-vscode-extensions.overlays.default ];

      mkPkgs = src: import src {
        inherit system overlays;
        config.allowUnfree = true;
      };

      systemProfiles = {
        common = ./modules/common;
        graphical = ./modules/graphical;
        work = ./modules/work;
        gaming = ./modules/gaming;
        server = ./modules/server;
        llama-cpp = ./modules/llama-cpp;
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
        let
          unstablePkgs = mkPkgs nixpkgs-unstable;
          masterPkgs = mkPkgs nixpkgs-master;
          hmModule = {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit unstablePkgs; };
          };
          baseModules = [
            agenix.nixosModules.default
            nix-flatpak.nixosModules.nix-flatpak
            home-manager.nixosModules.home-manager
            hmModule
          ];
        in
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit unstablePkgs;
            inherit masterPkgs;
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
                home-manager.extraSpecialArgs = { inherit unstablePkgs; };
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

      mkUser = { name, systemModule, profiles }: {
        inherit name systemModule profiles;
      };

      mkHostDef = { hostModule, systemProfiles ? [ ], users }: {
        inherit hostModule systemProfiles users;
      };

      hosts = {
        white-tower = mkHostDef {
          hostModule = ./hosts/white-tower/configuration.nix;
          systemProfiles = [ "llama-cpp" ];
          users = [
            (mkUser {
              name = "pbovbel";
              systemModule = ./users/pbovbel.nix;
              profiles = [ "gaming" ];
            })
            (mkUser {
              name = "rbovbel";
              systemModule = ./users/rbovbel.nix;
              profiles = [ "graphical" ];
            })
          ];
        };

        # pbovbel-dell = {
        #   hostModule = ./hosts/pbovbel-dell/configuration.nix;
        #   users = [
        #     {
        #       name = "pbovbel";
        #       systemModule = ./users/pbovbel.nix;
        #       profiles = [ "work" ];
        #     }
        #   ];
        # };

        # media = {
        #   hostModule = ./hosts/media/configuration.nix;
        #   systemProfiles = [ "server" ];
        #   users = [
        #     {
        #       name = "pbovbel";
        #       systemModule = ./users/pbovbel.nix;
        #       profiles = [ "headless" ];
        #     }
        #   ];
        # };

      };
    in {
      nixosConfigurations = lib.mapAttrs mkHost hosts;
    };
}
