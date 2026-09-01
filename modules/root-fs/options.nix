{lib, ...}: {
  options.rootFs = {
    _diskoContent = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      description = "Filesystem content supplied to the shared root partition layout.";
    };

    enable = lib.mkEnableOption "managed root filesystem layout";

    backend = lib.mkOption {
      type = lib.types.enum ["btrfs" "zfs"];
      default = "zfs";
      description = "Filesystem backend used for the root layout.";
    };

    impermanent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Reset the root filesystem at boot and persist declared state.";
    };

    encrypted = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Encrypt the root filesystem partition with LUKS.";
    };

    diskId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Disk id path for the main system disk.";
    };

    existingPartitions = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          efiDevice = lib.mkOption {
            type = lib.types.str;
            description = "Existing EFI system partition mounted at /boot.";
          };
          rootDevice = lib.mkOption {
            type = lib.types.str;
            description = "Existing partition used for the root filesystem.";
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
      description = "Swap partition size for the Disko layout.";
    };

    homeUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users that receive dedicated home filesystems.";
    };

    persistPath = lib.mkOption {
      type = lib.types.strMatching "^/.*";
      default = "/persist";
      description = "Mount path for persisted state.";
    };

    persistDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Directories to persist when impermanence is enabled.";
    };

    persistFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Files to persist when impermanence is enabled.";
    };

    volumes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          mountpoint = lib.mkOption {
            type = lib.types.strMatching "^/.*";
            description = "Absolute mountpoint for the persistent volume.";
          };
          autoSnapshot = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether scheduled local snapshots include this volume.";
          };
          quota = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional backend-specific volume size limit.";
          };
        };
      });
      default = {};
      description = "Additional persistent root-pool volumes.";
    };

    zfs.arcMaxPercent = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 50;
      description = "Maximum ZFS ARC size as a percentage of physical memory.";
    };
  };
}
