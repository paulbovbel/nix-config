{
  description = "pbovbel NixOS configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/0.1";
    nixpkgs-unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    tiny-dfr-nyan = {
      url = "github:paulbovbel/tiny-dfr-nyan";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    nixos-apple-silicon = {
      # OpenZFS 2.4 supports kernels through 7.0; newer Asahi releases use 7.1.
      url = "github:nix-community/nixos-apple-silicon/3902c801519264191a7c3dfec8dd1f9faeb38fd5";
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
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
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
    stylix,
    catppuccin,
    quadlet-nix,
    nixos-apple-silicon,
    tiny-dfr-nyan,
    ...
  }: let
    inherit (nixpkgs) lib;
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = lib.genAttrs systems;
    packageOverrides = final: prev: {
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
    };
    overlays = [
      nix-vscode-extensions.overlays.default
      packageOverrides
    ];

    mkPkgs = system: src:
      import src {
        inherit system overlays;
        config.allowUnfree = true;
      };

    profiles = import ./profiles;
    accountNames = ["abovbel" "pbovbel" "rbovbel"];
    profileEntries = lib.concatMap (userName:
      lib.mapAttrsToList (profileName: value: {
        name = "${userName}.${profileName}";
        inherit value;
      })
      profiles.${userName})
    (lib.attrNames profiles);
    invalidProfiles = map (profile: profile.name) (builtins.filter (profile:
      !(profile.value ? homeModules)
      || !builtins.isList profile.value.homeModules
      || !(profile.value ? systemModules)
      || !builtins.isList profile.value.systemModules
      || (profile.value ? graphical && !builtins.isBool profile.value.graphical))
    profileEntries);

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

    userHomeModules = user: let
      userProfiles = profiles.${user.name};
      selectedProfiles = map (profileName: userProfiles.${profileName}) user.profiles;
    in
      lib.concatMap (profile: profile.homeModules) selectedProfiles;

    userSystemModules = user: let
      userProfiles = profiles.${user.name};
    in
      lib.concatMap (profileName: userProfiles.${profileName}.systemModules) user.profiles;

    validateHost = name: cfg: let
      configuredUserNames = map (user: user.name) cfg.users;
      unknownAccounts = lib.subtractLists accountNames configuredUserNames;
      unknownUsers = lib.subtractLists (lib.attrNames profiles) configuredUserNames;
      knownUsers = builtins.filter (user: builtins.hasAttr user.name profiles) cfg.users;
      unknownProfiles = lib.concatMap (user:
        map (profileName: "${user.name}.${profileName}")
        (lib.subtractLists (lib.attrNames profiles.${user.name}) user.profiles))
      knownUsers;
    in
      assert lib.assertMsg (unknownAccounts == []) "Host ${name} selects unknown accounts: ${lib.concatStringsSep ", " unknownAccounts}";
      assert lib.assertMsg (unknownUsers == []) "Host ${name} selects unknown users: ${lib.concatStringsSep ", " unknownUsers}";
      assert lib.assertMsg (unknownProfiles == []) "Host ${name} selects unknown profiles: ${lib.concatStringsSep ", " unknownProfiles}";
      assert lib.assertMsg (invalidProfiles == []) "Profiles must define list-valued homeModules and systemModules, with optional boolean graphical: ${lib.concatStringsSep ", " invalidProfiles}"; cfg;

    mkHostSettings = name: configuredUserNames: unstablePkgs: {config, ...}: {
      assertions = [
        {
          assertion = config.networking.hostName == name;
          message = "Host ${name} configures networking.hostName as ${config.networking.hostName}";
        }
      ];

      rootFs.homeUsers = configuredUserNames;

      accounts = lib.genAttrs configuredUserNames (_: {enable = true;});

      nixpkgs = {
        inherit overlays;
        config.allowUnfree = true;
      };

      home-manager = {
        backupFileExtension = "backup";
        useGlobalPkgs = true;
        useUserPackages = true;
        sharedModules = [catppuccin.homeModules.catppuccin];
        extraSpecialArgs = {
          inherit unstablePkgs;
          inherit vscode-workspace-populator;
        };
      };
    };

    mkUserModules = users:
      map (user: {
        home-manager.users.${user.name}.imports = userHomeModules user;
      })
      users;

    mkHost = name: rawCfg: let
      cfg = validateHost name rawCfg;
      inherit (cfg) system;
      configuredUserNames = map (user: user.name) cfg.users;
      nixpkgsForHost =
        if cfg.useUnstablePackages or false
        then nixpkgs-unstable
        else nixpkgs;
      unstablePkgs = mkPkgs system nixpkgs-unstable;
    in
      nixpkgsForHost.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit agenix locus-vpn-client nixos-apple-silicon tiny-dfr-nyan unstablePkgs;
        };
        modules =
          [
            ./hosts/${name}/configuration.nix
            ./modules
            (mkHostSettings name configuredUserNames unstablePkgs)
          ]
          ++ externalModules
          ++ lib.unique (lib.concatMap userSystemModules cfg.users)
          ++ mkUserModules cfg.users;
      };

    hosts = {
      white-tower = import ./hosts/white-tower;
      rainbow-wave = import ./hosts/rainbow-wave;
      pbovbel-dell = import ./hosts/pbovbel-dell;
      becmac-pro = import ./hosts/becmac-pro;
      media = import ./hosts/media;
    };
    nixosConfigurations = lib.mapAttrs mkHost hosts;
  in {
    inherit nixosConfigurations;
    lib.hostNames = lib.attrNames hosts;
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      inherit (pkgs) attic-client;
    });
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          alejandra
          deadnix
          fd
          just
          python3
          ruff
          shellcheck
          shfmt
          statix
        ];
      };
    });
  };
}
