{
  config.moduleDocumentation.podman-server = {
    title = "Podman Server";
    category = "Infrastructure";
    summary = "Reusable Quadlet containers, shared paths, dependencies, and derived environment files.";
  };

  imports = [
    ./options.nix
    ./base.nix
    ./runtime.nix
    ./validation.nix
  ];
}
