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
          assertion = builtins.all (env: builtins.hasAttr env cfg.derivedEnvFiles) container.derivedEnvironmentFiles;
          message = "podmanServer.containers.${name} references unknown derivedEnvironmentFiles: ${lib.concatStringsSep ", " (builtins.filter (env: !(builtins.hasAttr env cfg.derivedEnvFiles)) container.derivedEnvironmentFiles)}";
        }
        {
          assertion = builtins.all (port: port.hostPort + port.count - 1 <= 65535 && port.containerPort + port.count - 1 <= 65535) container.ports;
          message = "podmanServer.containers.${name}.ports contains a range ending above 65535";
        }
      ])
      cfg.containers);
}
