{
  pkgs,
  nixpkgs,
  quadlet-nix,
  agenix,
}: let
  inherit (pkgs) lib;
  evaluate = import ./evaluate.nix {
    inherit nixpkgs quadlet-nix agenix;
    inherit (pkgs.stdenv.hostPlatform) system;
  };
  container = {quadlet.containerConfig.image = "docker.io/library/alpine:latest";};
  env = {variables.VALUE = "example";};
  configuration = extra:
    (evaluate (lib.recursiveUpdate {
        podmanServer.containers.app = container;
      }
      extra)).config;
  failedMessages = cfg: map (entry: entry.message) (builtins.filter (entry: !entry.assertion) cfg.assertions);
  rejects = needle: cfg:
    builtins.any (lib.hasInfix needle) (failedMessages cfg)
    && !(builtins.tryEval cfg.system.build.toplevel.drvPath).success;
  valid = configuration {
    podmanServer = {
      containers = {
        app = {
          dependsOn = ["database"];
          derivedEnvironmentFiles = ["left" "right"];
          ports = [
            {
              hostPort = 8080;
              containerPort = 80;
              openFirewall = true;
            }
            {
              hostPort = 9000;
              bindAddress = "127.0.0.1";
            }
            {
              hostPort = 9001;
              bindAddress = "::1";
            }
            {
              hostPort = 10000;
              containerPort = 20000;
              count = 3;
              protocol = "udp";
              openFirewall = true;
            }
          ];
          quadlet.containerConfig.publishPorts = ["127.0.0.1:11000-11002:12000-12002/udp"];
        };
        database = container;
      };
      derivedEnvFiles = {
        source = env;
        left = env // {derivedEnvironmentFiles = ["source"];};
        right = env // {derivedEnvironmentFiles = ["source"];};
      };
    };
  };
  tests = {
    validConfiguration = failedMessages valid == [] && (builtins.tryEval valid.system.build.toplevel.drvPath).success;
    portRendering =
      valid.virtualisation.quadlet.containers.app.containerConfig.publishPorts
      == [
        "127.0.0.1:11000-11002:12000-12002/udp"
        "8080:80/tcp"
        "127.0.0.1:9000:9000/tcp"
        "[::1]:9001:9001/tcp"
        "10000-10002:20000-20002/udp"
      ];
    explicitFirewall =
      valid.networking.firewall.allowedTCPPorts
      == [8080]
      && valid.networking.firewall.allowedUDPPorts == []
      && valid.networking.firewall.allowedUDPPortRanges
      == [
        {
          from = 10000;
          to = 10002;
        }
      ];
    containerOrdering = builtins.elem "database.service" valid.virtualisation.quadlet.containers.app.unitConfig.Requires;
    environmentOrdering = valid.systemd.services.podman-server-left-env.requires == ["podman-server-source-env.service"];
    missingContainer = rejects "containers has unknown dependencies: app -> absent" (configuration {
      podmanServer.containers.app.dependsOn = ["absent"];
    });
    containerCycle = rejects "containers has a dependency cycle" (configuration {
      podmanServer.containers = {
        app.dependsOn = ["other"];
        other = container // {dependsOn = ["app"];};
      };
    });
    selfDependency = rejects "containers has a dependency cycle" (configuration {
      podmanServer.containers.app.dependsOn = ["app"];
    });
    missingEnvironment = rejects "app references unknown derivedEnvironmentFiles: absent" (configuration {
      podmanServer.containers.app.derivedEnvironmentFiles = ["absent"];
    });
    missingTransitiveEnvironment = rejects "derivedEnvFiles has unknown dependencies: source -> absent" (configuration {
      podmanServer.containers.app.derivedEnvironmentFiles = ["source"];
      podmanServer.derivedEnvFiles.source = env // {derivedEnvironmentFiles = ["absent"];};
    });
    environmentCycle = rejects "derivedEnvFiles has a dependency cycle" (configuration {
      podmanServer.containers.app.derivedEnvironmentFiles = ["left"];
      podmanServer.derivedEnvFiles = {
        left = env // {derivedEnvironmentFiles = ["right"];};
        right = env // {derivedEnvironmentFiles = ["left"];};
      };
    });
    overflowingRange = rejects "range ending above 65535" (configuration {
      podmanServer.containers.app.ports = [
        {
          hostPort = 65535;
          count = 2;
        }
      ];
    });
  };
  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) tests);
in
  assert lib.assertMsg (failed == []) "Podman contract failures: ${lib.concatStringsSep ", " failed}";
    pkgs.runCommand "podman-server-contracts" {} "touch $out"
