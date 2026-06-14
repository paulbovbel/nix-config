{lib, ...}: let
  snapshotValueType = lib.types.oneOf [lib.types.bool lib.types.str];
  autoSnapshotType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.nullOr snapshotValueType;
        default = null;
        description = "Whether zfs-auto-snapshot includes this dataset.";
      };

      frequent = lib.mkOption {
        type = lib.types.nullOr snapshotValueType;
        default = null;
        description = "Frequent zfs-auto-snapshot policy.";
      };

      hourly = lib.mkOption {
        type = lib.types.nullOr snapshotValueType;
        default = null;
        description = "Hourly zfs-auto-snapshot policy.";
      };

      daily = lib.mkOption {
        type = lib.types.nullOr snapshotValueType;
        default = null;
        description = "Daily zfs-auto-snapshot policy.";
      };

      weekly = lib.mkOption {
        type = lib.types.nullOr snapshotValueType;
        default = null;
        description = "Weekly zfs-auto-snapshot policy.";
      };

      monthly = lib.mkOption {
        type = lib.types.nullOr snapshotValueType;
        default = null;
        description = "Monthly zfs-auto-snapshot policy.";
      };
    };
  };
  datasetType = parentPath:
    lib.types.submodule ({name, ...}: {
      options = {
        path = lib.mkOption {
          type = lib.types.str;
          default = "${parentPath}/${name}";
          readOnly = true;
          description = "Generated mount path for this dataset.";
        };

        options = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Raw ZFS dataset options.";
        };

        autoSnapshot = lib.mkOption {
          type = autoSnapshotType;
          default = {};
          description = "zfs-auto-snapshot policy for this dataset.";
        };

        children = lib.mkOption {
          type = lib.types.lazyAttrsOf (datasetType "${parentPath}/${name}");
          default = {};
          description = "Child datasets.";
        };
      };
    });
in {
  options.storage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable shared host storage datasets and paths.";
    };

    datasets = lib.mkOption {
      type = lib.types.lazyAttrsOf (datasetType "/storage");
      default = {};
      description = "Nested shared host storage datasets.";
    };
  };
}
