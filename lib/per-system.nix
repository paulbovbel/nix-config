{
  inputs,
  system,
  nixosConfigurations,
  ciHostNames,
  hostEvaluations,
  containerImages,
  readImages,
  sourceRoot,
}: let
  inherit (inputs) nixpkgs agenix disko disko-zfs impermanence quadlet-nix;
  inherit (nixpkgs) lib;
  pkgs = import nixpkgs {inherit system;};
  docs = import ../modules/documentation/evaluate.nix {
    inherit inputs pkgs containerImages sourceRoot;
  };
  tailnetPolicy = import ../hosts/tailnet-policy.nix;
  tailnet-policy = pkgs.writeText "tailnet-policy.json" (builtins.toJSON (import ../modules/tailnet/policy.nix {
    inherit lib nixosConfigurations;
    inherit (tailnetPolicy) policy containerGrants;
  }));
  rootFsImpermanenceTest = backend:
    import ../modules/root-fs/tests/root-fs-impermanence.nix {
      inherit backend disko disko-zfs impermanence nixpkgs pkgs;
      root = sourceRoot;
    };
  checks =
    {
      inherit (docs) module-docs-check;
      inherit tailnet-policy;
      registry-contracts = pkgs.writeText "registry-contracts.json" (builtins.toJSON (import ../modules/deployment/tests/registry-contracts.nix));
      tailnet-policy-contracts = import ../modules/tailnet/tests/contracts.nix {inherit pkgs;};
      # Force evaluation of every host without making their derivations build dependencies.
      host-evaluations = pkgs.writeText "host-evaluations.json" (
        builtins.unsafeDiscardStringContext (builtins.toJSON hostEvaluations)
      );
      podman-server-contracts = import ../modules/podman-server/tests/contracts.nix {inherit pkgs nixpkgs quadlet-nix agenix containerImages readImages;};
      storage-contracts = import ../modules/storage/tests/contracts.nix {inherit pkgs nixpkgs disko disko-zfs;};
      alloy-config = import ../modules/monitor/tests/alloy-config.nix {inherit pkgs nixosConfigurations;};
    }
    // lib.optionalAttrs (system == "x86_64-linux") {
      podman-server-exposure = import ../modules/podman-server/tests/exposure.nix {inherit pkgs quadlet-nix agenix;};
      game-streaming-contracts = import ../modules/game-streaming/tests/contracts.nix {inherit pkgs nixpkgs;};
      authentik-blueprint = import ../modules/authentik/tests/blueprint.nix {inherit pkgs quadlet-nix;};
      github-runner-disposable = import ../modules/github-runner/tests/disposable.nix {inherit pkgs;};
      # TODO: Add end-to-end Btrfs and ZFS USB installer state-migration tests.
      root-fs-btrfs-impermanence = rootFsImpermanenceTest "btrfs";
      root-fs-zfs-impermanence = rootFsImpermanenceTest "zfs";
    };
in {
  inherit checks;
  packages = {
    rookie = inputs.rookie-cli.packages.${system}.default;
    inherit (pkgs) attic-client;
    inherit (docs) module-docs;
    inherit tailnet-policy;
    ci-hosts = pkgs.linkFarm "ci-hosts" (map (name: {
        inherit name;
        path = nixosConfigurations.${name}.config.system.build.toplevel;
      })
      ciHostNames);
    ci-checks = pkgs.linkFarm "ci-checks" checks;
  };
  devShells.default = pkgs.mkShell {
    packages = with pkgs; [
      actionlint
      age
      agenix.packages.${system}.default
      curl
      jq
      alejandra
      deadnix
      fd
      gcx
      just
      nixos-anywhere
      nixos-rebuild
      openssh
      prometheus.cli
      (python3.withPackages (ps: [ps.tenacity]))
      ruff
      shellcheck
      shfmt
      statix
      zstd
    ];
  };
}
