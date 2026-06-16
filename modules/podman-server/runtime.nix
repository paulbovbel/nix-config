{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.podmanServer;
  active = cfg.containers != {};

  derivedEnvUnits = names: map (name: "podman-server-${name}-env.service") names;
  derivedEnvFiles = names: map (name: cfg.derivedEnvFiles.${name}.path) names;
  volumeHostPath = volume: let
    parts = lib.splitString ":" volume;
    hostPath = lib.head parts;
  in
    lib.optional (lib.length parts > 1 && lib.hasPrefix "/" hostPath) hostPath;
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
  in
    lib.mkMerge [
      (quadletConfig
        // {
          containerConfig = builtins.removeAttrs quadletConfig.containerConfig ["name"];
        })
      {
        unitConfig = {
          Wants = lib.mkBefore ["network-online.target"];
          After = lib.mkBefore (["network-online.target"] ++ afterUnits);
          Requires = lib.mkBefore requiredUnits;
          RequiresMountsFor = lib.mkAfter (lib.unique (lib.concatMap volumeHostPath config.virtualisation.quadlet.containers.${name}.containerConfig.volumes));
        };

        containerConfig = {
          inherit name;
          networks = lib.mkBefore [config.virtualisation.quadlet.networks.apps.ref];
          environmentFiles = lib.mkAfter (container.secretEnvironmentFiles ++ derivedEnvFilePaths);
          podmanArgs = lib.mkBefore ["--no-healthcheck"];
        };
      }
      (lib.mkIf (container.build != null) {
        containerConfig.image = config.virtualisation.quadlet.builds.${name}.ref;
      })
    ];

  mkQuadletBuild = build:
    removeNulls (lib.filterAttrs (key: _: !(lib.hasPrefix "_" key) && key != "ref") build);
  mkQuadletBuilds = containers:
    lib.mapAttrs (_: mkQuadletBuild) (lib.filterAttrs (_: build: build != null) (lib.mapAttrs (_: container: container.build) containers));

  renderDerivedEnvFile = name: envFile: let
    derivedEnvUnitNames = derivedEnvUnits envFile.derivedEnvironmentFiles;
    derivedEnvFilePaths = derivedEnvFiles envFile.derivedEnvironmentFiles;
    renderedVariables = lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key}=${value}") envFile.variables);
  in {
    description = "Render Podman server ${name} environment";
    wants = derivedEnvUnitNames ++ envFile.wants;
    after = derivedEnvUnitNames ++ envFile.after;
    path = [pkgs.coreutils] ++ envFile.packages;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
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

  declaredContainerNames = lib.attrNames cfg.containers;
in {
  config = lib.mkIf active {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    virtualisation.quadlet = {
      networks.apps.networkConfig.name = "apps";
      builds = mkQuadletBuilds cfg.containers;
      containers = lib.mapAttrs mkQuadletContainer cfg.containers;
    };

    systemd.services = lib.mapAttrs' (name: envFile: lib.nameValuePair "podman-server-${name}-env" (renderDerivedEnvFile name envFile)) cfg.derivedEnvFiles;

    system.activationScripts.podman-server-prune-containers = lib.stringAfter ["etc"] ''
      declared_names=(${lib.escapeShellArgs declaredContainerNames})

      is_declared_container() {
        local candidate="$1"
        local declared
        for declared in "''${declared_names[@]}"; do
          if [ "$candidate" = "$declared" ]; then
            return 0
          fi
        done
        return 1
      }

      for container in $(${pkgs.podman}/bin/podman ps --all --format '{{.Names}}' 2>/dev/null); do
        if is_declared_container "$container"; then
          continue
        fi

        load_state="$(${pkgs.systemd}/bin/systemctl show --property=LoadState --value "$container.service" 2>/dev/null || true)"
        if [ "$load_state" = not-found ]; then
          ${pkgs.coreutils}/bin/timeout 20s ${pkgs.podman}/bin/podman rm --force --time 10 --ignore "$container" 2>/dev/null || true
          ${pkgs.coreutils}/bin/timeout 5s ${pkgs.systemd}/bin/systemctl reset-failed "$container.service" 2>/dev/null || true
        fi
      done
    '';
  };
}
