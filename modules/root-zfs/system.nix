{
  config,
  lib,
  ...
}: let
  cfg = config.rootZfs;
  zrootMountpoints = lib.filter (mountpoint: lib.isString mountpoint && lib.hasPrefix "/" mountpoint) (
    lib.mapAttrsToList (_: dataset: dataset.mountpoint or null) config.disko.devices.zpool.zroot.datasets
  );
in {
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      fileSystems = lib.genAttrs zrootMountpoints (_: {
        neededForBoot = true;
      });

      services.zfs.autoSnapshot = {
        enable = true;
        frequent = 0;
      };

      services.zfs.autoScrub = {
        enable = true;
        pools = ["zroot"];
      };

      boot.initrd.systemd.services.zfs-arc-limit = {
        description = "Limit ZFS ARC to ${toString cfg.arcMaxPercent}% of system memory";
        wantedBy = ["initrd.target"];
        after = ["systemd-modules-load.service"];
        before = ["zfs-import-zroot.service"];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
          read -r _ mem_kib _ </proc/meminfo
          printf '%s\n' "$((mem_kib * 1024 * ${toString cfg.arcMaxPercent} / 100))" > /sys/module/zfs/parameters/zfs_arc_max
        '';
      };

      boot.initrd.luks.devices."crypted" = lib.mkIf cfg.encrypted {
        crypttabExtraOpts = ["tpm2-device=auto"];
      };
    }

    (lib.mkIf cfg.impermanent {
      environment.persistence.${cfg.persistPath} = {
        # Reduces mount clutter from persistence bind mounts.
        hideMounts = true;
        directories = lib.unique cfg.persistDirectories;
        files = lib.unique cfg.persistFiles;
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
    })
  ]);
}
