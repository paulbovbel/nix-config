{lib, ...}: {
  options.impermanenceRoot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable impermanent root filesystem layout and rollback.";
    };

    diskId = lib.mkOption {
      type = lib.types.str;
      description = "Disk id path for main system disk (e.g. /dev/disk/by-id/...)";
    };

    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "32G";
      description = "Swap partition size for disko layout.";
    };

    persistPath = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Mount path for persisted state.";
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
      description = "Directories to persist when impermanence-root is enabled.";
    };
    persistFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Files to persist when impermanence-root is enabled.";
    };
  };
}
