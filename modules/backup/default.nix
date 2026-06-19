{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.backup;
  hasTargets = cfg.targets != [];
  hasPaths = cfg.paths != {};
  sourcePaths = map (path: lib.removeSuffix "/" path.source) (lib.attrValues cfg.paths);
  readOnlyPaths = sourcePaths ++ lib.optional (cfg.identityFile != null) cfg.identityFile;
  serviceName = target: "backup-${builtins.replaceStrings ["@" ":" "/" "."] ["-" "-" "-" "-"] (lib.strings.sanitizeDerivationName target)}";
  pathsJson = pkgs.writeText "backup-paths.json" (builtins.toJSON (lib.mapAttrsToList (name: path: {
      inherit name;
      source = lib.removeSuffix "/" path.source;
      inherit (path) destination excludes;
    })
    cfg.paths));
  backupScript = pkgs.writeShellApplication {
    name = "backup";
    runtimeInputs = [pkgs.coreutils pkgs.jq pkgs.openssh pkgs.rsync];
    text = builtins.readFile ./backup.sh;
  };

  targetService = target: let
    name = serviceName target;
  in
    lib.nameValuePair name {
      description = "Push backups to ${target}";
      restartIfChanged = false;
      wants = ["network-online.target"];
      after = ["network-online.target"];
      unitConfig.RequiresMountsFor = readOnlyPaths;
      environment = lib.optionalAttrs (cfg.identityFile != null) {
        IDENTITY_FILE = cfg.identityFile;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe backupScript} ${lib.escapeShellArgs [target cfg.remoteRoot pathsJson]}";
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
        assertion = hasTargets == hasPaths;
        message = "backup.targets and backup.paths must either both be set or both be empty.";
      }
    ];

    systemd.services = lib.mkIf hasTargets (lib.listToAttrs (map targetService cfg.targets));
    systemd.timers = lib.mkIf hasTargets (lib.listToAttrs (map targetTimer cfg.targets));
  };
}
