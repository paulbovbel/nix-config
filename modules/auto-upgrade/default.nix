{
  config,
  graphicalSessions,
  lib,
  pkgs,
  ...
}: let
  cfg = config.autoUpgrade;
  autoUpgradeTool = pkgs.writeShellApplication {
    name = "auto-upgrade";
    runtimeInputs = [config.nix.package graphicalSessions pkgs.gitMinimal pkgs.mailutils pkgs.systemd];
    text = ''
      exec ${pkgs.python3}/bin/python ${./auto_upgrade.py} "$@"
    '';
  };
  identityFile = config.age.secrets.nix-config-auto-upgrade-key.path;
  outbox = "/var/lib/auto-upgrade/reports";
in {
  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.msmtp.enable;
        message = "autoUpgrade.enable requires programs.msmtp.enable for reports.";
      }
    ];

    age.secrets.nix-config-auto-upgrade-key = {
      file = ../../secrets/common/pbovbel-id_rsa.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    programs.ssh.knownHosts."github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

    systemd.services = {
      nixos-upgrade = {
        description = "Guarded NixOS automatic upgrade";
        restartIfChanged = false;
        startAt = "03:00";
        wants = ["agenix-install-secrets.service" "network-online.target"];
        after = ["agenix-install-secrets.service" "network-online.target"];
        environment.GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -i ${identityFile} -o IdentitiesOnly=yes";
        script = ''
          exec ${autoUpgradeTool}/bin/auto-upgrade run \
            --target ${lib.escapeShellArg config.networking.hostName} \
            --repository ${lib.escapeShellArg cfg.repository} \
            --branch ${lib.escapeShellArg cfg.branch} \
            --working-directory /run/nixos-upgrade \
            --outcome /run/nixos-upgrade/outcome.json \
            --reboot-window-lower 03:00 \
            --reboot-window-upper 05:00
        '';
        postStop = ''
          ${autoUpgradeTool}/bin/auto-upgrade report \
            --recipient ${lib.escapeShellArg cfg.email} \
            --outbox ${outbox} \
            --outcome /run/nixos-upgrade/outcome.json
        '';
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "nixos-upgrade";
          StateDirectory = "auto-upgrade";
          WorkingDirectory = "/run/nixos-upgrade";
        };
        unitConfig.X-StopOnRemoval = false;
      };

      auto-upgrade-report-retry = {
        description = "Retry queued NixOS automatic upgrade reports";
        startAt = "hourly";
        wants = ["agenix-install-secrets.service" "network-online.target"];
        after = ["agenix-install-secrets.service" "network-online.target"];
        script = ''
          ${autoUpgradeTool}/bin/auto-upgrade retry-reports --outbox ${outbox}
        '';
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "auto-upgrade";
        };
      };
    };

    systemd.timers = {
      nixos-upgrade.timerConfig = {
        RandomizedDelaySec = "45min";
        FixedRandomDelay = true;
        Persistent = true;
      };
      auto-upgrade-report-retry.timerConfig = {
        RandomizedDelaySec = "5min";
        Persistent = true;
      };
    };

    rootFs.persistDirectories = ["/var/lib/auto-upgrade"];
  };
}
