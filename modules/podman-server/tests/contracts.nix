{
  pkgs,
  nixpkgs,
  quadlet-nix,
  agenix,
  containerImages,
  readImages,
}: let
  inherit (pkgs) lib;
  evaluate = import ./evaluate.nix {
    inherit nixpkgs quadlet-nix agenix;
    inherit (pkgs.stdenv.hostPlatform) system;
  };
  parseImages = text: readImages (builtins.toFile "test-images.Dockerfile" text);
  catalogEntry = "FROM ${containerImages.postgres} AS example";
  container = {quadlet.containerConfig.image = containerImages.postgres;};
  env = {variables.VALUE = "example";};
  disabled = (evaluate {}).config;
  storageOnly = (evaluate {storage.enable = true;}).config;
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
              exposure = ["wan"];
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
              hostPort = 9443;
              exposure = ["tailnet"];
            }
            {
              hostPort = 15000;
              count = 2;
              protocol = "udp";
              exposure = ["tailnet"];
            }
            {
              hostPort = 10000;
              containerPort = 20000;
              count = 3;
              protocol = "udp";
              exposure = ["wan"];
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
    disabledHasNoWorkloadState =
      disabled.storage.datasets
      == {}
      && disabled.podmanServer.derivedEnvFiles == {}
      && disabled.rootFs.persistDirectories == [];
    disabledHasNoRuntime =
      !disabled.virtualisation.podman.enable
      && disabled.virtualisation.quadlet.containers == {}
      && !(disabled.systemd.services ? podman-server-lan-env)
      && !(disabled.systemd.timers ? podman-auto-update);
    storageDoesNotActivatePodman =
      storageOnly.storage.datasets
      == {}
      && !storageOnly.virtualisation.podman.enable;
    activeDoesNotDeclareDatasets = valid.storage.datasets == {};
    catalogPins = builtins.all (image: builtins.match ".+:[^@]+@sha256:[0-9a-f]{64}" image != null) (lib.attrValues containerImages);
    catalogParsing = parseImages "# Example catalog\n\n${catalogEntry}\n" == {example = containerImages.postgres;};
    emptyCatalog = !(builtins.tryEval (parseImages "# No images\n")).success;
    duplicateCatalogAliases = !(builtins.tryEval (parseImages "${catalogEntry}\n${catalogEntry}\n")).success;
    unpinnedCatalogEntry = !(builtins.tryEval (parseImages "FROM docker.io/library/postgres:16-alpine AS example\n")).success;
    registryAutoUpdatesDisabled =
      valid.virtualisation.quadlet.containers.app.containerConfig.autoUpdate
      == null
      && !(valid.systemd.timers ? podman-auto-update);
    unpinnedImage = rejects "must use a digest-pinned registry image" (configuration {
      podmanServer.containers.app.quadlet.containerConfig.image = "docker.io/library/postgres:16-alpine";
    });
    malformedDigest = rejects "must use a digest-pinned registry image" (configuration {
      podmanServer.containers.app.quadlet.containerConfig.image = "docker.io/library/postgres@sha256:invalid";
    });
    imageChangeRestarts = let
      changed = configuration {
        podmanServer.containers.app.quadlet.containerConfig.image = containerImages.authentik;
      };
    in
      (configuration {}).systemd.services.app.restartTriggers != changed.systemd.services.app.restartTriggers;
    validConfiguration = failedMessages valid == [] && (builtins.tryEval valid.system.build.toplevel.drvPath).success;
    portRendering =
      valid.virtualisation.quadlet.containers.app.containerConfig.publishPorts
      == [
        "127.0.0.1:11000-11002:12000-12002/udp"
        "8080:80/tcp"
        "127.0.0.1:9000:9000/tcp"
        "[::1]:9001:9001/tcp"
        "9443:9443/tcp"
        "15000-15001:15000-15001/udp"
        "10000-10002:20000-20002/udp"
      ];
    explicitFirewall =
      valid.networking.firewall.allowedTCPPorts
      == [8080]
      && valid.networking.firewall.allowedUDPPorts == [1900]
      && valid.networking.firewall.allowedUDPPortRanges
      == [
        {
          from = 10000;
          to = 10002;
        }
      ];
    generatedUPnP =
      valid.upnp.forwards
      == {
        podman-tcp-8080 = {
          from = 8080;
          to = 8080;
          proto = "tcp";
        };
        podman-udp-10000 = {
          from = 10000;
          to = 10000;
          proto = "udp";
        };
        podman-udp-10001 = {
          from = 10001;
          to = 10001;
          proto = "udp";
        };
        podman-udp-10002 = {
          from = 10002;
          to = 10002;
          proto = "udp";
        };
      };
    tailnetFirewall =
      valid.networking.firewall.interfaces.tailscale0.allowedTCPPorts
      == [9443]
      && valid.networking.firewall.interfaces.tailscale0.allowedUDPPortRanges
      == [
        {
          from = 15000;
          to = 15001;
        }
      ];
    customTailnetInterface = let
      cfg = configuration {
        services.tailscale.interfaceName = "tailnet-test";
        podmanServer.containers.app.ports = [
          {
            hostPort = 8080;
            exposure = ["tailnet"];
          }
        ];
      };
    in
      cfg.networking.firewall.interfaces.tailnet-test.allowedTCPPorts
      == [8080]
      && cfg.networking.firewall.allowedTCPPorts == []
      && cfg.upnp.forwards == {};
    loopbackUPnP = rejects "UPnP forwarding requires an all-interface IPv4 bind" (configuration {
      podmanServer.containers.app.ports = [
        {
          hostPort = 8080;
          exposure = ["wan"];
          bindAddress = "127.0.0.1";
        }
      ];
    });
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
    environmentSelfDependency = rejects "derivedEnvFiles has a dependency cycle" (configuration {
      podmanServer.derivedEnvFiles.source = env // {derivedEnvironmentFiles = ["source"];};
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
