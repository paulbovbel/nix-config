{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.podmanServer;
  active = cfg.containers != {};

  derivedEnvUnits = names: map (name: "podman-server-${name}-env.service") names;
  envGraph = (import ./graph.nix {inherit lib;}) (lib.mapAttrs (_: env: env.derivedEnvironmentFiles) cfg.derivedEnvFiles);
  derivedEnvFiles = names: map (name: cfg.derivedEnvFiles.${name}.path) (builtins.filter (name: builtins.hasAttr name cfg.derivedEnvFiles) names);
  derivedEnvDefinitions = names: lib.genAttrs (envGraph.closure names) (name: cfg.derivedEnvFiles.${name});
  ageSecretFilesByPath = lib.mapAttrs' (_: secret: lib.nameValuePair secret.path secret.file) config.age.secrets;
  derivedEnvSecretPaths = names:
    lib.concatMap (name: cfg.derivedEnvFiles.${name}.secretEnvironmentFiles) (envGraph.closure names);
  secretRestartTriggers = container:
    map
    (path: ageSecretFilesByPath.${path})
    (builtins.filter
      (path: builtins.hasAttr path ageSecretFilesByPath)
      (lib.unique (container.secretEnvironmentFiles ++ derivedEnvSecretPaths container.derivedEnvironmentFiles)));
  storageUnits = lib.optional config.storage.enable "zfs-mount.service";
  removeNulls = value:
    if lib.isAttrs value
    then lib.filterAttrs (_: nested: nested != null) (lib.mapAttrs (_: removeNulls) value)
    else value;

  mkQuadletContainer = name: container: let
    dependencyUnits = map (dependency: "${dependency}.service") container.dependsOn;
    derivedEnvUnitNames = derivedEnvUnits container.derivedEnvironmentFiles;
    derivedEnvFilePaths = derivedEnvFiles container.derivedEnvironmentFiles;
    requiredUnits = dependencyUnits ++ derivedEnvUnitNames;
    afterUnits = dependencyUnits ++ derivedEnvUnitNames;
    quadletConfig = removeNulls (lib.filterAttrs (key: _: !(lib.hasPrefix "_" key) && key != "ref") container.quadlet);
    image = container.quadlet.containerConfig.image or null;
    archiveImage = image != null && (lib.hasPrefix "docker-archive:" image || lib.hasPrefix "oci-archive:" image);
  in
    lib.mkMerge [
      (quadletConfig
        // {
          containerConfig = builtins.removeAttrs quadletConfig.containerConfig ["name"];
        })
      {
        unitConfig = {
          Wants = lib.mkBefore ["network-online.target"];
          After = lib.mkBefore (["network-online.target"] ++ storageUnits ++ afterUnits);
          Requires = lib.mkBefore (storageUnits ++ requiredUnits);
        };

        containerConfig = {
          inherit name;
          autoUpdate = lib.mkDefault (
            if container.build != null
            then "local"
            else if archiveImage
            then null
            else "registry"
          );
          networks = lib.mkBefore [config.virtualisation.quadlet.networks.apps.ref];
          environmentFiles = lib.mkAfter (container.secretEnvironmentFiles ++ derivedEnvFilePaths);
          publishPorts = lib.mkAfter (map renderPort container.ports);
          podmanArgs = lib.mkBefore ["--no-healthcheck"];
        };

        serviceConfig.ExecStartPre = lib.mkBefore ["-${pkgs.podman}/bin/podman rm --force --ignore ${name}"];
      }
      (lib.mkIf (container.build != null) {
        containerConfig.image = config.virtualisation.quadlet.builds.${name}.ref;
      })
    ];

  mkQuadletBuild = build:
    removeNulls (lib.filterAttrs (key: _: !(lib.hasPrefix "_" key) && key != "ref") build);
  mkQuadletBuilds = containers:
    lib.mapAttrs (_: mkQuadletBuild) (lib.filterAttrs (_: build: build != null) (lib.mapAttrs (_: container: container.build) containers));

  mkContainerService = name: container: {
    description = "Run ${name} Podman container";
    restartTriggers =
      [
        (pkgs.writeText "podman-server-${name}-config" (builtins.toJSON container))
        (pkgs.writeText "podman-server-${name}-derived-env-config" (builtins.toJSON (derivedEnvDefinitions container.derivedEnvironmentFiles)))
      ]
      ++ secretRestartTriggers container;
  };

  renderPort = port: let
    range = start: toString start + lib.optionalString (port.count > 1) "-${toString (start + port.count - 1)}";
    address =
      if port.bindAddress == null
      then ""
      else if lib.hasInfix ":" port.bindAddress
      then "[${port.bindAddress}]:"
      else "${port.bindAddress}:";
  in "${address}${range port.hostPort}:${range port.containerPort}/${port.protocol}";
  firewallPorts = scope: protocol:
    builtins.filter (port: builtins.elem scope port.exposure && port.protocol == protocol) publishedPorts;
  publishedPorts = lib.concatMap (container: container.ports) (lib.attrValues cfg.containers);
  firewallSingles = scope: protocol: lib.unique (map (port: port.hostPort) (builtins.filter (port: port.count == 1) (firewallPorts scope protocol)));
  firewallRanges = scope: protocol:
    lib.unique (map (port: {
      from = port.hostPort;
      to = port.hostPort + port.count - 1;
    }) (builtins.filter (port: port.count > 1) (firewallPorts scope protocol)));
  firewallRules = scope: {
    allowedTCPPorts = firewallSingles scope "tcp";
    allowedUDPPorts = firewallSingles scope "udp";
    allowedTCPPortRanges = firewallRanges scope "tcp";
    allowedUDPPortRanges = firewallRanges scope "udp";
  };
  restrictedPorts = builtins.filter (port: !(builtins.elem "wan" port.exposure)) publishedPorts;
  exposureFirewall = command: ''
    ${command} -t mangle -N podman-server-exposure 2>/dev/null || true
    ${command} -t mangle -F podman-server-exposure
    ${command} -t mangle -A podman-server-exposure -i ${lib.escapeShellArg cfg.networkInterface} -j RETURN
    ${lib.concatMapStringsSep "\n" (port: let
        portRange = toString port.hostPort + lib.optionalString (port.count > 1) ":${toString (port.hostPort + port.count - 1)}";
        interfaceMatch = lib.optionalString (builtins.elem "tailnet" port.exposure) "! -i ${lib.escapeShellArg config.services.tailscale.interfaceName}";
      in ''
        ${command} -t mangle -A podman-server-exposure ${interfaceMatch} -p ${port.protocol} --dport ${portRange} -m addrtype --dst-type LOCAL -j DROP
      '')
      restrictedPorts}
    ${command} -t mangle -C PREROUTING -j podman-server-exposure 2>/dev/null || ${command} -t mangle -I PREROUTING -j podman-server-exposure
  '';
  upnpForwards = lib.listToAttrs (lib.concatMap (port:
    map (offset: let
      hostPort = port.hostPort + offset;
    in
      lib.nameValuePair "podman-${port.protocol}-${toString hostPort}" {
        from = hostPort;
        to = hostPort;
        proto = port.protocol;
      }) (lib.range 0 (port.count - 1)))
  (builtins.filter (port: builtins.elem "wan" port.exposure) publishedPorts));

  renderDerivedEnvFile = name: envFile: let
    derivedEnvUnitNames = derivedEnvUnits envFile.derivedEnvironmentFiles;
    derivedEnvFilePaths = derivedEnvFiles envFile.derivedEnvironmentFiles;
    renderedVariables = lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key}=${value}") envFile.variables);
  in {
    description = "Render environment file for Podman server ${name}";
    requires = derivedEnvUnitNames;
    inherit (envFile) wants;
    after = derivedEnvUnitNames ++ envFile.after;
    path = [pkgs.coreutils] ++ envFile.packages;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      EnvironmentFile = envFile.environmentFiles ++ envFile.secretEnvironmentFiles ++ derivedEnvFilePaths;
    };
    script = ''
      install -d -m ${envFile.directoryMode} "$(dirname ${lib.escapeShellArg envFile.path})"
      ${lib.optionalString envFile.createIfMissing ''
        if [ -s ${lib.escapeShellArg envFile.path} ]; then
          exit 0
        fi
      ''}
      cat >${lib.escapeShellArg envFile.path} <<EOF
      ${renderedVariables}
      EOF
      chmod ${envFile.mode} ${lib.escapeShellArg envFile.path}
    '';
  };
in {
  config = lib.mkIf active {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    virtualisation.quadlet = {
      networks.apps.networkConfig = {
        name = "apps";
        interfaceName = cfg.networkInterface;
      };
      builds = mkQuadletBuilds cfg.containers;
      containers = lib.mapAttrs mkQuadletContainer cfg.containers;
    };

    networking.firewall =
      firewallRules "wan"
      // {
        interfaces.${config.services.tailscale.interfaceName} = firewallRules "tailnet";
        # Filter published host ports before Podman's DNAT bypasses the INPUT chain.
        extraCommands = exposureFirewall "iptables" + exposureFirewall "ip6tables";
        extraStopCommands = lib.concatMapStringsSep "\n" (command: ''
          ${command} -t mangle -D PREROUTING -j podman-server-exposure 2>/dev/null || true
          ${command} -t mangle -F podman-server-exposure 2>/dev/null || true
          ${command} -t mangle -X podman-server-exposure 2>/dev/null || true
        '') ["iptables" "ip6tables"];
      };

    upnp.forwards = upnpForwards;

    systemd.services = lib.mkMerge [
      (lib.mapAttrs' (name: envFile: lib.nameValuePair "podman-server-${name}-env" (renderDerivedEnvFile name envFile)) cfg.derivedEnvFiles)
      (lib.mapAttrs mkContainerService cfg.containers)
    ];

    systemd.timers."podman-auto-update" = {
      description = "Schedule automatic updates for Podman containers";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily"; # Change to your preferred schedule
        Persistent = true;
      };
    };
  };
}
