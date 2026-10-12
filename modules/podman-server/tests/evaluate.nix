{
  nixpkgs,
  quadlet-nix,
  agenix,
  system,
}: extra:
nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ../../documentation/options.nix
    quadlet-nix.nixosModules.quadlet
    agenix.nixosModules.default
    ../default.nix
    ../../upnp
    ../../storage/options.nix
    ({
      config,
      lib,
      ...
    }: {
      options = {
        rootFs.persistDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
        };
      };
      config = {
        podmanServer.derivedEnvFiles = lib.mkIf (config.podmanServer.containers != {}) {
          lan.variables = {
            LAN_ADDRESS = lib.mkForce "192.0.2.1";
            LAN_NETWORK = lib.mkForce "192.0.2.0/24";
          };
        };
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
        users.users.pbovbel.isNormalUser = true;
        system.stateVersion = "26.05";
      };
    })
    extra
  ];
}
