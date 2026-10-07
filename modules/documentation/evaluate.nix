{
  inputs,
  containerImages,
  sourceRoot,
}: system: let
  inherit (inputs) self nixpkgs nixpkgs-unstable agenix disko disko-zfs impermanence quadlet-nix;
  pkgs = import nixpkgs {inherit system;};
  unstablePkgs = import nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  evaluation = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {inherit unstablePkgs containerImages;};
    modules = [
      agenix.nixosModules.default
      disko.nixosModules.disko
      disko-zfs.nixosModules.default
      impermanence.nixosModules.impermanence
      quadlet-nix.nixosModules.quadlet
      ../default.nix
      ../../profiles/options.nix
      {
        networking.hostName = "module-docs";
        networking.domain = "example.invalid";
        tailscale.domain = "tailnet.example.invalid";
        time.timeZone = "UTC";
        system.stateVersion = "26.05";
      }
    ];
  };
  revision = self.shortRev or (self.dirtyShortRev or "dirty");
  sourceRevision = self.rev or "main";
in
  import ./build.nix {
    inherit pkgs revision sourceRevision sourceRoot;
    inherit (nixpkgs) lib;
    inherit (evaluation) config options;
    repositoryUrl = "https://github.com/paulbovbel/nix-config";
  }
