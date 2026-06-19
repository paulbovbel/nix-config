{lib, ...}: let
  pathType = lib.types.submodule ({name, ...}: {
    options = {
      source = lib.mkOption {
        type = lib.types.str;
        description = "Local path to push to backup targets.";
      };

      destination = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Directory name under backup.remoteRoot on backup targets.";
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
    targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["12345@usw-s001.rsync.net" "offsite"];
      description = "SSH targets that receive the same backup paths.";
    };

    remoteRoot = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Remote directory that receives backup path subdirectories.";
    };

    identityFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SSH private key used to connect to backup targets.";
    };

    timer = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for backup runs.";
    };

    paths = lib.mkOption {
      type = lib.types.attrsOf pathType;
      default = {};
      description = "Named local paths to push to backup targets.";
    };
  };
}
