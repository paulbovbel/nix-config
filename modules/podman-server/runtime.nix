{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.podmanServer;
  inherit (cfg) user;
  active = cfg.containers != {};

  envValue = value:
    if lib.isBool value
    then lib.boolToString value
    else toString value;

  line = key: value: "${key}=${value}";
  lines = key: values: map (line key) values;
  derivedEnvUnits = names: map (name: "podman-server-${name}-env.service") names;
  derivedEnvFiles = names: map (name: cfg.derivedEnvFiles.${name}.path) names;

  renderContainer = name: container: let
    dependencyUnits = map (dependency: "${dependency}.service") container.dependsOn;
    derivedEnvUnitNames = derivedEnvUnits container.derivedEnvironmentFiles;
    derivedEnvFilePaths = derivedEnvFiles container.derivedEnvironmentFiles;
    secretEnvUnits = lib.optional (container.secretEnvironmentFiles != []) "agenix.service";
    requiredUnits = dependencyUnits ++ derivedEnvUnitNames ++ secretEnvUnits ++ container.unitRequires;
    afterUnits = dependencyUnits ++ derivedEnvUnitNames ++ secretEnvUnits ++ container.unitAfter;
    containerUser = "${toString user.uid}:${toString user.gid}";
  in
    lib.concatStringsSep "\n" (
      [
        "[Unit]"
        "Wants=network-online.target"
        "After=network-online.target"
      ]
      ++ lib.optional (requiredUnits != []) "Requires=${lib.concatStringsSep " " requiredUnits}"
      ++ lib.optional (afterUnits != []) "After=${lib.concatStringsSep " " afterUnits}"
      ++ lines "RequiresMountsFor" container.requiresMountsFor
      ++ [
        ""
        "[Container]"
        (line "ContainerName" name)
        "Network=apps"
        (line "Image" container.image)
      ]
      ++ lib.mapAttrsToList (key: value: line "Environment" "${key}=${envValue value}") container.environment
      ++ lines "EnvironmentFile" (container.environmentFiles ++ container.secretEnvironmentFiles ++ derivedEnvFilePaths)
      ++ lines "PublishPort" container.ports
      ++ lines "Volume" container.volumes
      ++ lines "Tmpfs" container.tmpfs
      ++ lines "AddDevice" container.devices
      ++ lines "AddCapability" container.capabilities
      ++ lines "Sysctl" container.sysctls
      ++ [(line "User" containerUser)]
      ++ lib.optional (container.command != null) (line "Exec" container.command)
      ++ lib.optional container.privileged "PodmanArgs=--privileged"
      ++ [
        ""
        "[Service]"
      ]
      ++ lib.optional (container.execStopPre != null) "ExecStopPre=${container.execStopPre}"
      ++ [
        ""
        "[Install]"
        "WantedBy=multi-user.target"
        ""
      ]
    );

  renderDerivedEnvFile = name: envFile: let
    derivedEnvUnitNames = derivedEnvUnits envFile.derivedEnvironmentFiles;
    derivedEnvFilePaths = derivedEnvFiles envFile.derivedEnvironmentFiles;
    renderedVariables = lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key}=${value}") envFile.variables);
  in {
    description = "Render Podman server ${name} environment";
    wants = lib.optional (envFile.secretEnvironmentFiles != []) "agenix.service" ++ derivedEnvUnitNames ++ envFile.wants;
    after = lib.optional (envFile.secretEnvironmentFiles != []) "agenix.service" ++ derivedEnvUnitNames ++ envFile.after;
    path = [pkgs.coreutils] ++ envFile.packages;
    serviceConfig = {
      Type = "oneshot";
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

  quadletFiles = lib.mapAttrs' (name: container:
    lib.nameValuePair "containers/systemd/${name}.container" {
      text = renderContainer name container;
    })
  cfg.containers;
in {
  config = lib.mkIf active {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    environment.etc =
      quadletFiles
      // {
        "containers/systemd/apps.network".text = ''
          [Network]
          NetworkName=apps
        '';
      };

    systemd.services = lib.mapAttrs' (name: envFile: lib.nameValuePair "podman-server-${name}-env" (renderDerivedEnvFile name envFile)) cfg.derivedEnvFiles;
  };
}
