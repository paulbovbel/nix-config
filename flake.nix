{
  description = "pbovbel NixOS configuration";

  inputs = {
    # Fetch actual assets rather than Git LFS pointers for remote builds.
    self.lfs = true;

    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/0.1";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs-unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
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
      url = "github:nix-community/nixos-apple-silicon/release-2026-07-30";
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

  outputs = inputs @ {
    self,
    nixpkgs,
    agenix,
    disko,
    disko-zfs,
    impermanence,
    quadlet-nix,
    ...
  }: let
    inherit (nixpkgs) lib;
    configurationBranch = let
      branch = builtins.getEnv "NIX_CONFIG_BRANCH";
    in
      if branch == ""
      then "main"
      else branch;
    configurationRevision = let
      revision = builtins.getEnv "NIX_CONFIG_REVISION";
    in
      if revision != ""
      then revision
      else self.rev or self.dirtyRev or null;
    systems = ["aarch64-linux" "x86_64-linux"];
    forAllSystems = lib.genAttrs systems;
    pkgsFor = forAllSystems (system: import nixpkgs {inherit system;});
    overlays = [inputs.nix-vscode-extensions.overlays.default (import ./overlays)];
    readImages = import ./modules/podman-server/read-images.nix;
    containerImages = readImages ./images.Dockerfile;
    hosts = import ./hosts;
    hostEvaluations = lib.mapAttrs (name: metadata:
      import ./modules/deployment/tests/evaluate-host.nix {
        inherit metadata;
        host = self.nixosConfigurations.${name};
      })
    hosts;
    mkHost = import ./hosts/mk-host.nix {
      inherit inputs overlays configurationBranch configurationRevision containerImages;
    };
    mkInstaller = import ./modules/deployment/usb/mk-installer.nix {
      inherit nixpkgs hosts mkHost;
      inherit (inputs) nixos-apple-silicon;
    };
    mkDocs = import ./modules/documentation/evaluate.nix {
      inherit inputs containerImages;
      sourceRoot = ./.;
    };
  in {
    nixosConfigurations = lib.mapAttrs (name: cfg: mkHost name cfg []) hosts;
    lib = {
      inherit hosts mkInstaller;
      hostNames = lib.attrNames hosts;
      ciHostNames = lib.attrNames (lib.filterAttrs (_: host: host.ciBuild) hosts);
    };
    packages = forAllSystems (system: let
      pkgs = pkgsFor.${system};
      docs = mkDocs system;
    in {
      inherit (pkgs) attic-client;
      inherit (docs) module-docs;
      ci-hosts = pkgs.linkFarm "ci-hosts" (
        map (name: {
          inherit name;
          path = self.nixosConfigurations.${name}.config.system.build.toplevel;
        })
        self.lib.ciHostNames
      );
      ci-checks = pkgs.linkFarm "ci-checks" self.checks.${system};
    });
    checks = forAllSystems (system: let
      pkgs = pkgsFor.${system};
      rootFsImpermanenceTest = backend:
        import ./modules/root-fs/tests/root-fs-impermanence.nix {
          inherit backend disko disko-zfs impermanence nixpkgs pkgs;
          root = ./.;
        };
    in
      {
        inherit (mkDocs system) module-docs-check;
        # Force evaluation of every host without making their derivations build dependencies.
        host-evaluations = pkgs.writeText "host-evaluations.json" (
          builtins.unsafeDiscardStringContext (builtins.toJSON hostEvaluations)
        );
        podman-server-contracts = import ./modules/podman-server/tests/contracts.nix {inherit pkgs nixpkgs quadlet-nix agenix containerImages readImages;};
        storage-contracts = import ./modules/storage/tests/contracts.nix {inherit pkgs nixpkgs disko disko-zfs;};
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        podman-server-exposure = import ./modules/podman-server/tests/exposure.nix {inherit pkgs quadlet-nix agenix;};
        game-streaming-contracts = import ./modules/game-streaming/tests/contracts.nix {inherit pkgs nixpkgs;};
        authentik-blueprint = import ./modules/authentik/tests/blueprint.nix {inherit pkgs quadlet-nix;};
        # TODO: Add end-to-end Btrfs and ZFS USB installer state-migration tests.
        root-fs-btrfs-impermanence = rootFsImpermanenceTest "btrfs";
        root-fs-zfs-impermanence = rootFsImpermanenceTest "zfs";
      });
    devShells = forAllSystems (system: let
      pkgs = pkgsFor.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          actionlint
          agenix.packages.${system}.default
          alejandra
          deadnix
          fd
          gcx
          just
          (python3.withPackages (ps: [ps.tenacity]))
          ruff
          shellcheck
          shfmt
          statix
        ];
      };
    });
  };
}
