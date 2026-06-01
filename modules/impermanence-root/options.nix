{lib, ...}: {
  options.impermanenceRoot = {
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
