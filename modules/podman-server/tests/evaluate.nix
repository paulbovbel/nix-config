{
  nixpkgs,
  quadlet-nix,
  agenix,
  system,
}: extra:
nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    quadlet-nix.nixosModules.quadlet
    agenix.nixosModules.default
    ../default.nix
    ../../upnp
    ../../storage/options.nix
    ({lib, ...}: {
      options = {
        rootFs.persistDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
        };
      };
      config = {
        _module.args = {
          lanAddressCommand = "printf 192.0.2.1";
          lanNetworkCommand = "printf 192.0.2.0/24";
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
