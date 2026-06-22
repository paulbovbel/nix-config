{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.backup;
  hasTargets = cfg.targets != {};
  sourcePaths = targetCfg: map (path: lib.removeSuffix "/" path.source) (lib.attrValues targetCfg.paths);
  readOnlyPaths = targetCfg: sourcePaths targetCfg ++ lib.optional (cfg.identityFile != null) cfg.identityFile;
  serviceName = target: "backup-${builtins.replaceStrings ["@" ":" "/" "."] ["-" "-" "-" "-"] (lib.strings.sanitizeDerivationName target)}";
  pathsJson = target: targetCfg:
    pkgs.writeText "backup-paths-${serviceName target}.json" (builtins.toJSON (lib.mapAttrsToList (name: path: {
        inherit name;
        source = lib.removeSuffix "/" path.source;
        inherit (path) destination excludes;
      })
      targetCfg.paths));
  backupScript = pkgs.writeShellApplication {
    name = "backup";
    runtimeInputs = [pkgs.coreutils pkgs.jq pkgs.openssh pkgs.rsync];
    text = builtins.readFile ./backup.sh;
  };

  targetService = target: targetCfg: let
    name = serviceName target;
  in
    lib.nameValuePair name {
      description = "Push backups to ${target}";
      restartIfChanged = false;
      wants = ["network-online.target"];
      after = ["network-online.target"];
      unitConfig.RequiresMountsFor = readOnlyPaths targetCfg;
      environment = lib.optionalAttrs (cfg.identityFile != null) {
        IDENTITY_FILE = cfg.identityFile;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe backupScript} ${lib.escapeShellArgs [target cfg.remoteRoot (pathsJson target targetCfg)]}";
        StateDirectory = name;
      };
    };

  targetTimer = target:
    lib.nameValuePair (serviceName target) {
      description = "Push backups to ${target}";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.timer;
        Persistent = true;
      };
    };
in {
  imports = [./options.nix];

  config = {
    assertions = [
      {
        assertion = lib.all (target: target.paths != {}) (lib.attrValues cfg.targets);
        message = "backup.targets entries must each define at least one path.";
      }
    ];

    systemd.services = lib.mkIf hasTargets (lib.mapAttrs' targetService cfg.targets);
    systemd.timers = lib.mkIf hasTargets (lib.mapAttrs' (target: _: targetTimer target) cfg.targets);
  };
}
