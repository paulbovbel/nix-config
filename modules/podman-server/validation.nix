{
  config,
  lib,
  ...
}: let
  cfg = config.podmanServer;
  checkGraph = import ./graph.nix {inherit lib;};
  containerGraph = checkGraph (lib.mapAttrs (_: container: container.dependsOn) cfg.containers);
  envGraph = checkGraph (lib.mapAttrs (_: env: env.derivedEnvironmentFiles) cfg.derivedEnvFiles);
  graphAssertions = label: graph: [
    {
      assertion = graph.missing == [];
      message = "podmanServer ${label} has unknown dependencies: ${lib.concatStringsSep ", " graph.missing}";
    }
    {
      assertion = graph.cycles == [];
      message = "podmanServer ${label} has a dependency cycle involving: ${lib.concatStringsSep ", " graph.cycles}";
    }
  ];
in {
  config.assertions =
    graphAssertions "containers" containerGraph
    ++ graphAssertions "derivedEnvFiles" envGraph
    ++ lib.concatLists (lib.mapAttrsToList (name: container: [
        {
          assertion = let
            image = container.quadlet.containerConfig.image or null;
          in
            container.build
            != null
            || (image
              != null
              && (lib.hasPrefix "docker-archive:" image
                || lib.hasPrefix "oci-archive:" image
                || builtins.match ".+@sha256:[0-9a-f]{64}" image != null));
          message = "podmanServer.containers.${name} must use a digest-pinned registry image or a Nix-built image.";
        }
        {
          assertion = builtins.all (env: builtins.hasAttr env cfg.derivedEnvFiles) container.derivedEnvironmentFiles;
          message = "podmanServer.containers.${name} references unknown derivedEnvironmentFiles: ${lib.concatStringsSep ", " (builtins.filter (env: !(builtins.hasAttr env cfg.derivedEnvFiles)) container.derivedEnvironmentFiles)}";
        }
        {
          assertion = builtins.all (port: port.hostPort + port.count - 1 <= 65535 && port.containerPort + port.count - 1 <= 65535) container.ports;
          message = "podmanServer.containers.${name}.ports contains a range ending above 65535";
        }
        {
          assertion = builtins.all (port: !(builtins.elem "wan" port.exposure) || port.bindAddress == null || port.bindAddress == "0.0.0.0") container.ports;
          message = "podmanServer.containers.${name}.ports UPnP forwarding requires an all-interface IPv4 bind";
        }
      ])
      cfg.containers);
}
