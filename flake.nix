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

        prismlauncher-unwrapped = prev.prismlauncher-unwrapped.overrideAttrs (oldAttrs: {
          postPatch =
            (oldAttrs.postPatch or "")
            + ''
              substituteInPlace launcher/minecraft/auth/MinecraftAccount.h \
                --replace-fail 'bool ownsMinecraft() const { return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft; }' \
                               'bool ownsMinecraft() const { return true; }'
            '';
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
      configuredUserNames = map (user: user.name) cfg.users;
      unknownUsers = lib.subtractLists (lib.attrNames userProfiles) configuredUserNames;
      knownUsers = builtins.filter (user: builtins.hasAttr user.name userProfiles) cfg.users;
      unknownProfiles = lib.concatMap (user:
        map (profileName: "${user.name}.${profileName}")
        (lib.subtractLists (lib.attrNames userProfiles.${user.name}) user.profiles))
      knownUsers;
      nixpkgsForHost =
        if cfg.useUnstablePackages or false
        then nixpkgs-unstable
        else nixpkgs;
      unstablePkgs = mkPkgs nixpkgs-unstable;
    in
      assert lib.assertMsg (unknownUsers == []) "Host ${name} selects unknown users: ${lib.concatStringsSep ", " unknownUsers}";
      assert lib.assertMsg (unknownProfiles == []) "Host ${name} selects unknown profiles: ${lib.concatStringsSep ", " unknownProfiles}";
        nixpkgsForHost.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit agenix locus-vpn-client unstablePkgs pcp;
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
              ({config, ...}: {
                assertions = [
                  {
                    assertion = config.networking.hostName == name;
                    message = "Host ${name} configures networking.hostName as ${config.networking.hostName}";
                  }
                ];

                rootZfs.homeUsers = configuredUserNames;

                nixpkgs = {
                  inherit overlays;
                  config.allowUnfree = true;
                };

                home-manager = {
                  backupFileExtension = "backup";
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = {
                    inherit unstablePkgs;
                    inherit vscode-workspace-populator;
                  };
                };
              })
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

    hosts = {
      white-tower = import ./hosts/white-tower;
      rainbow-wave = import ./hosts/rainbow-wave;
      pbovbel-dell = import ./hosts/pbovbel-dell;
      media = import ./hosts/media;
    };
    nixosConfigurations = lib.mapAttrs mkHost hosts;
    hostPackages = lib.mapAttrs' (name: host:
      lib.nameValuePair "nixos-${name}" host.config.system.build.toplevel)
    nixosConfigurations;
    hostChecks = lib.mapAttrs' (name: host:
      lib.nameValuePair "nixos-${name}" (let
        failedAssertions = builtins.filter (assertion: !assertion.assertion) host.config.assertions;
        assertionMessage = lib.concatMapStringsSep "\n" (assertion: assertion.message) failedAssertions;
      in
        assert lib.assertMsg (failedAssertions == []) assertionMessage;
        assert builtins.deepSeq host.config.system.build.toplevel.drvPath true;
          host.config.system.build.toplevel))
    nixosConfigurations;
  in {
    inherit nixosConfigurations;
    lib.hostNames = lib.attrNames hosts;
    packages.${system} = hostPackages;
    checks.${system} = hostChecks;
  };
}
