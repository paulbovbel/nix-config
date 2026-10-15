{
  config,
  lib,
  ...
}: let
  cfg = config.githubRunner;
  githubKnownHost.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
in {
  imports = [./options.nix];

  config = lib.mkMerge [
    {
      moduleDocumentation.github-runner = {
        title = "GitHub Runner";
        category = "Infrastructure";
        summary = "Disposable per-job self-hosted GitHub Actions runner.";
      };
    }
    (lib.mkIf cfg.enable {
      age.secrets = {
        github-runner-token.file = ../../secrets/server/github-runner-token.age;
        github-runner-ssh-key = {
          file = ../../secrets/common/pbovbel-id_rsa.age;
          owner = "github-runner";
          group = "github-runner";
          mode = "0400";
        };
      };

      programs.ssh.knownHosts."github.com" = githubKnownHost;

      users.groups.github-runner.gid = 989;
      users.users.github-runner = {
        isSystemUser = true;
        uid = 989;
        group = "github-runner";
      };

      # Runner exit powers off the guest; the host replaces the entire job environment.
      systemd.services."container@github-runner".serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "1s";
      };

      containers.github-runner = {
        autoStart = true;
        ephemeral = true;
        bindMounts = {
          "/run/secrets/github-runner-token" = {
            hostPath = config.age.secrets.github-runner-token.path;
            isReadOnly = true;
          };
          "/run/agenix/github-runner-ssh-key" = {
            hostPath = config.age.secrets.github-runner-ssh-key.path;
            isReadOnly = true;
          };
        };
        config = {pkgs, ...}: {
          # Use the newer release package with GitHub LFS endpoint normalization.
          nix.package = pkgs.nixVersions.latest;

          nix.settings = {
            fallback = true;
            extra-platforms = config.boot.binfmt.emulatedSystems;
            experimental-features = [
              "nix-command"
              "flakes"
            ];
          };

          programs.ssh.knownHosts."github.com" = githubKnownHost;

          users.groups.github-runner.gid = 989;
          users.users.github-runner = {
            isSystemUser = true;
            uid = 989;
            group = "github-runner";
            home = "/var/lib/github-runner/work";
            createHome = true;
          };

          services.github-runners.nix-config = {
            enable = true;
            ephemeral = true;
            inherit (cfg) extraLabels url;
            name =
              if cfg.name == null
              then config.networking.hostName
              else cfg.name;
            replace = true;
            tokenFile = "/run/secrets/github-runner-token";
            tokenType = "access";
            extraPackages = [pkgs.openssh];
            workDir = "/var/lib/github-runner/work";
            extraEnvironment.GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -i /run/agenix/github-runner-ssh-key -o IdentitiesOnly=yes";
            user = "github-runner";
            group = "github-runner";
            serviceOverrides = {
              ReadWritePaths = ["/var/lib/github-runner/work"];
              # Never register a second runner inside a used container, including
              # after retryable listener failures (exit code 2).
              Restart = lib.mkForce "no";
              RestartForceExitStatus = lib.mkForce [];
            };
          };

          systemd.services.github-runner-nix-config = {
            onSuccess = ["poweroff.target"];
            onFailure = ["poweroff.target"];
          };

          systemd.tmpfiles.rules = [
            "d /var/lib/github-runner/work 0700 github-runner github-runner -"
          ];

          system.stateVersion = "26.05";
        };
      };
    })
  ];
}
