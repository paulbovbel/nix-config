{lib, ...}: {
  options.moduleDocumentation.podman-server = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Podman Server";
      summary = "Reusable Quadlet containers, shared paths, dependencies, and derived environment files.";
    };
  };

  imports = [
    ./options.nix
    ./base.nix
    ./runtime.nix
  ];
}
