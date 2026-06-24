{
  description = "pbovbel NixOS configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/0.1";
    nixpkgs-unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    locus-vpn-client = {
      url = "git+ssh://git@github.com/locusrobotics/locus-vpn-client.git";
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
      url = "git+ssh://git@github.com/locusrobotics/vscode-workspace-populator.git";
      flake = false;
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko-zfs = {
      url = "github:numtide/disko-zfs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        disko.follows = "disko";
      };
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
    catppuccin = {
      url = "github:catppuccin/nix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    pcp = {
      url = "github:performancecopilot/pcp/7.1.5";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    nix-flatpak,
    disko,
    disko-zfs,
    agenix,
    impermanence,
    locus-vpn-client,
    nix-vscode-extensions,
    vscode-workspace-populator,
    catppuccin,
    stylix,
    quadlet-nix,
    pcp,
    ...
  }: let
    inherit (nixpkgs) lib;
    system = "x86_64-linux";
    overlays = [
      nix-vscode-extensions.overlays.default
      (final: prev: {
        headsetcontrol = prev.headsetcontrol.overrideAttrs (_: {
          # Last released version of headsetcontrol doesn't include fixes for Audeze Maxwell headset
          # https://github.com/Sapd/HeadsetControl/pull/412
          version = "4d57d17af8b49d436b01822a23a3871aa7646f11";
          src = final.fetchFromGitHub {
            owner = "Sapd";
            repo = "HeadsetControl";
            rev = "4d57d17af8b49d436b01822a23a3871aa7646f11";
            hash = "sha256-N59GYF5XEIdm2zeIbsHwFA6dkXaCCyi3oxIWuUVL1fk=";
          };
        });

        netbootxyz-efi = prev.netbootxyz-efi.overrideAttrs (_: {
          version = "3.0.2";
          src = final.fetchurl {
            url = "https://github.com/netbootxyz/netboot.xyz/releases/download/3.0.2/netboot.xyz.efi";
            hash = "sha256-4PbBxZPh2grQg/nXoOOjWAhR9gJqNgR53oriAUrv0i8=";
          };
        });

        netbootxyz-legacy = final.stdenvNoCC.mkDerivation {
          pname = "netboot.xyz-legacy";
          version = "3.0.2";
          src = final.fetchurl {
            url = "https://github.com/netbootxyz/netboot.xyz/releases/download/3.0.2/netboot.xyz-legacy.efi";
            hash = "sha256-TJNf+oy0lr2YOKJ+h2ooae+uIHD25J6T9AsPN01LiFM=";
          };

          dontUnpack = true;

          postInstall = ''
            cp $src $out
          '';
        };
      })
    ];

    mkPkgs = src:
      import src {
        inherit system overlays;
        config.allowUnfree = true;
      };

    userSystemProfiles = {
      common = ./profiles/common;
      graphical = ./profiles/graphical;
      work = ./profiles/work;
      gaming = ./profiles/gaming;
      headless = ./profiles/headless;
    };

    userProfiles = import ./users;

    userHomeModules = user: let
      profiles = userProfiles.${user.name};
      hasGraphicalProfile = lib.any (profileName: profiles.${profileName}.systemProfile != "headless") user.profiles;
    in
      map (profileName: profiles.${profileName}.module) user.profiles
      ++ [
        catppuccin.homeModules.catppuccin
      ]
      ++ lib.optionals hasGraphicalProfile [
        stylix.homeModules.stylix
      ];

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
    in
      nixpkgsForHost.lib.nixosSystem {
        inherit system;
        specialArgs = {
          hostUsers = cfg.users;
          inherit agenix locus-vpn-client unstablePkgs pcp;
          inherit (cfg) tailscaleDomain;
        };
        modules =
          [
            ./hosts/${name}/configuration.nix
            ./modules
            agenix.nixosModules.default
            nix-flatpak.nixosModules.nix-flatpak
            disko.nixosModules.disko
            disko-zfs.nixosModules.default
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.home-manager
            catppuccin.nixosModules.catppuccin
            quadlet-nix.nixosModules.quadlet
            "${pcp}/build/nix/nixos-module.nix"
            {
              caddy.publicDomain = cfg.publicDomain;

              nixpkgs = {
                inherit overlays;
                config.allowUnfree = true;
              };

              home-manager = {
                backupFileExtension = "backup";
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit (cfg) tailscaleDomain;
                  inherit unstablePkgs;
                  inherit vscode-workspace-populator;
                };
              };
            }
          ]
          # User profiles still imply their workstation/headless base module.
          ++ map (profile: userSystemProfiles.${profile}) (lib.unique (lib.flatten (map userSystemProfileNames cfg.users)))
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
