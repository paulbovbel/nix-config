{lib, ...}: {
  options.rootZfs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable ZFS root filesystem layout.";
    };

    impermanent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Rollback the root dataset to a blank snapshot at boot and persist declared state.";
    };

    encrypted = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Encrypt the root ZFS partition with LUKS.";
    };

    diskId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Disk id path for main system disk (e.g. /dev/disk/by-id/...)";
    };

    existingPartitions = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          efiDevice = lib.mkOption {
            type = lib.types.str;
            description = "Existing EFI system partition mounted at /boot.";
          };
          zfsDevice = lib.mkOption {
            type = lib.types.str;
            description = "Existing partition used as the zroot vdev.";
          };
          swapDevice = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional existing partition used for randomly encrypted swap.";
          };
        };
      });
      default = null;
      description = "Existing partitions to use without modifying their parent partition table.";
    };

    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "32G";
      description = "Swap partition size for disko layout.";
    };

    arcMaxPercent = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 50;
      description = "Maximum ZFS ARC size as a percentage of physical memory.";
    };

    homeUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users that receive dedicated home datasets.";
    };

    persistPath = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Mount path for persisted state.";
    };

    datasets = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.anything;
      default = {};
      description = "Additional zroot dataset fragments for the root ZFS layout.";
    };

    rootDataset = lib.mkOption {
      type = lib.types.str;
      default = "zroot/root";
      description = "ZFS dataset used for root rollback.";
    };

    blankSnapshot = lib.mkOption {
      type = lib.types.str;
      default = "blank";
      description = "Snapshot name used for root rollback.";
    };

    persistDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Directories to persist when rootZfs.impermanent is enabled.";
    };

    persistFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Files to persist when rootZfs.impermanent is enabled.";
    };
  };
}
