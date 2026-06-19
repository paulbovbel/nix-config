{lib, ...}: let
  pathType = lib.types.submodule ({name, ...}: {
    options = {
      source = lib.mkOption {
        type = lib.types.str;
        description = "Local path to push to rsync.net.";
      };

      destination = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Directory name under backup.remoteRoot on rsync.net.";
      };

      excludes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "rsync exclude patterns for this path.";
      };
    };
  });
in {
  options.backup = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable scheduled rsync.net backups.";
    };

    account = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "12345@usw-s001.rsync.net";
      description = "rsync.net SSH account in user@host form.";
    };

    remoteRoot = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Remote directory that receives backup path subdirectories.";
    };

    identityFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SSH private key used to connect to rsync.net.";
    };

    timer = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for backup runs.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra arguments appended to every rsync invocation.";
    };

    paths = lib.mkOption {
      type = lib.types.attrsOf pathType;
      default = {};
      description = "Named local paths to push to rsync.net.";
    };
  };
}
