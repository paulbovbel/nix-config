{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.githubRunner;
  runnerPath = config.storage.datasets.app.children.github-runner.path;
  githubKnownHost.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
in {
  options.moduleDocumentation.github-runner = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "GitHub Runner";
      summary = "Containerized self-hosted GitHub Actions runner.";
    };
  };

  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.storage.enable;
        message = "githubRunner.enable requires storage.enable for persistent runner state.";
      }
    ];

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

    storage.datasets.app.children.github-runner = {};

    users.groups.github-runner.gid = 989;
    users.users.github-runner = {
      isSystemUser = true;
      uid = 989;
      group = "github-runner";
    };

    systemd.services."container@github-runner".serviceConfig.ExecStartPost = lib.mkAfter [
      "${pkgs.systemd}/bin/systemctl --machine=github-runner is-active --quiet github-runner-nix-config.service"
    ];

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
        "/var/lib/github-runner" = {
          hostPath = runnerPath;
          isReadOnly = false;
        };
      };
      config = {pkgs, ...}: {
        nix.settings.extra-platforms = config.boot.binfmt.emulatedSystems;
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

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
          inherit (cfg) extraLabels url;
          name =
            if cfg.name == null
            then config.networking.hostName
            else cfg.name;
          replace = true;
          tokenFile = "/run/secrets/github-runner-token";
          extraPackages = [pkgs.openssh];
          workDir = "/var/lib/github-runner/work";
          extraEnvironment.GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -i /run/agenix/github-runner-ssh-key -o IdentitiesOnly=yes";
          user = "github-runner";
          group = "github-runner";
          serviceOverrides = {
            ReadWritePaths = ["/var/lib/github-runner/work"];
          };
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/github-runner/work 0700 github-runner github-runner -"
        ];

        system.stateVersion = "26.05";
      };
    };
  };
}
