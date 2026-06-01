{
  config,
  lib,
  ...
}: let
  cfg = config.impermanenceRoot;
in {
  config = {
    fileSystems.${cfg.persistPath}.neededForBoot = true;

    environment.persistence.${cfg.persistPath} = {
      hideMounts = true;
      directories = lib.unique cfg.persistDirectories;
      files = lib.unique cfg.persistFiles;
    };

    boot.initrd.systemd.services.zfs-rollback-root = {
      description = "Rollback zroot/root to @blank snapshot";
      wantedBy = ["initrd.target"];
      after = ["zfs-import-zroot.service"];
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
