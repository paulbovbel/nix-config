{
  config,
  lib,
  ...
}: let
  cfg = config.impermanenceRoot;
  zrootMountpoints = lib.filter (mountpoint: lib.isString mountpoint && lib.hasPrefix "/" mountpoint) (
    lib.mapAttrsToList (_: dataset: dataset.mountpoint or null) config.disko.devices.zpool.zroot.datasets
  );
in {
  config = lib.mkIf cfg.enable {
    fileSystems = lib.genAttrs zrootMountpoints (_: {
      neededForBoot = true;
    });

    environment.persistence.${cfg.persistPath} = {
      # Reduces mount clutter from persistence bind mounts.
      hideMounts = true;
      directories = lib.unique cfg.persistDirectories;
      files = lib.unique cfg.persistFiles;
    };

    services.zfs.autoSnapshot = {
      enable = true;
      frequent = 0;
    };

    services.zfs.autoScrub.enable = true;

    boot.initrd.luks.devices."crypted" = lib.mkIf cfg.encrypted {
      crypttabExtraOpts = ["tpm2-device=auto"];
    };

    boot.initrd.systemd.services.zfs-rollback-root = {
      description = "Reset impermanent root ZFS dataset to the blank boot snapshot";
      wantedBy = ["initrd.target"];
      after = ["zfs-import-zroot.service"];
      # Must run before / is mounted so rollback applies to the live root.
      before = ["sysroot.mount"];
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";
      script = ''
        if zfs list -t snapshot -H -o name ${cfg.rootDataset}@${cfg.blankSnapshot} >/dev/null 2>&1; then
          echo "zfs-rollback-root: rolling back ${cfg.rootDataset}@${cfg.blankSnapshot}"
          zfs rollback -r ${cfg.rootDataset}@${cfg.blankSnapshot}
        else
          echo "zfs-rollback-root: WARNING snapshot ${cfg.rootDataset}@${cfg.blankSnapshot} not found; skipping rollback"
        fi
      '';
    };
  };
}
