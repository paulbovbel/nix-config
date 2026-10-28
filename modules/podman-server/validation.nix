{
  config,
  lib,
  ...
}: let
  cfg = config.podmanServer;
  checkGraph = import ./graph.nix {inherit lib;};
  # Namespace sharing is an ordering edge too, so it shares cycle detection.
  containerGraph = checkGraph (lib.mapAttrs (_: container:
    container.dependsOn
    ++ lib.optional (container.networkNamespaceOf != null) container.networkNamespaceOf)
  cfg.containers);
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
          # Networks are derived, so a raw list would concatenate with the
          # derived attachment rather than replace it.
          assertion = container.quadlet.containerConfig.networks == [];
          message = "podmanServer.containers.${name} must select its network with networkNamespaceOf instead of quadlet.containerConfig.networks";
        }
        {
          # Podman rejects published ports on a joined namespace, and the owner
          # already carries each sharer's name as an alias.
          assertion =
            container.networkNamespaceOf
            == null
            || (container.ports
              == []
              && container.quadlet.containerConfig.publishPorts == []
              && container.quadlet.containerConfig.networkAliases == []);
          message = "podmanServer.containers.${name} must publish ports through its networkNamespaceOf owner, which already answers to this container's name";
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
