{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.backup;
  sourcePaths = map (path: lib.removeSuffix "/" path.source) (lib.attrValues cfg.paths);
  readOnlyPaths = sourcePaths ++ lib.optional (cfg.identityFile != null) cfg.identityFile;

  destination = path: "${cfg.account}:${cfg.remoteRoot}/${path.destination}/";

  pathScript = name: path: let
    source = lib.removeSuffix "/" path.source;
    excludeArgs = lib.concatMapStringsSep " " (pattern: "--exclude ${lib.escapeShellArg pattern}") path.excludes;
    extraArgs = lib.escapeShellArgs cfg.extraArgs;
  in ''
    source=${lib.escapeShellArg source}
    remote=${lib.escapeShellArg (destination path)}
    test -e "$source"

    echo "[rsync-net-backup] starting ${name}: $source -> $remote"
    path_start=$(date +%s)

    if [ -d "$source" ]; then
      source="$source/"
    fi

    if ! rsync \
      --archive \
      --hard-links \
      --delete \
      --mkpath \
      --numeric-ids \
      --human-readable \
      --stats \
      ${excludeArgs} \
      ${extraArgs} \
      "$source" \
      "$remote"; then
      echo "[rsync-net-backup] failed ${name}" >&2
      exit 1
    fi

    path_end=$(date +%s)
    echo "[rsync-net-backup] finished ${name} in $((path_end - path_start))s"
  '';

  backupScript = pkgs.writeShellApplication {
    name = "rsync-net-backup";
    runtimeInputs = [pkgs.coreutils pkgs.openssh pkgs.rsync];
    text = ''
      set -euo pipefail

      known_hosts="$STATE_DIRECTORY/known_hosts"
      export RSYNC_RSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$known_hosts${lib.optionalString (cfg.identityFile != null) " -i ${cfg.identityFile}"}"

      echo "[rsync-net-backup] backup started"
      backup_start=$(date +%s)

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList pathScript cfg.paths)}

      backup_end=$(date +%s)
      echo "[rsync-net-backup] backup finished in $((backup_end - backup_start))s"
    '';
  };
in {
  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.account != "";
        message = "backup.account must be set when backup.enable is true.";
      }
      {
        assertion = cfg.paths != {};
        message = "backup.paths must contain at least one path when backup.enable is true.";
      }
    ];

    systemd.services.rsync-net-backup = {
      description = "Push backups to rsync.net";
      restartIfChanged = false;
      wants = ["network-online.target"];
      after = ["network-online.target"];
      unitConfig.RequiresMountsFor = readOnlyPaths;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe backupScript;
        StateDirectory = "rsync-net-backup";

        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = "read-only";
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = readOnlyPaths;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
      };
    };

    systemd.timers.rsync-net-backup = {
      description = "Push backups to rsync.net";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.timer;
        Persistent = true;
      };
    };
  };
}
