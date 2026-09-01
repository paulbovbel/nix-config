{
  config,
  lib,
  ...
}: let
  cfg = config.rootFs;
  enabled = cfg.enable && cfg.backend == "zfs";
  homeDatasets = lib.listToAttrs (map (name: {
      name = "root/home/${name}";
      value = {
        type = "zfs_fs";
        mountpoint = "/home/${name}";
      };
    })
    cfg.homeUsers);
  extraDatasets = lib.mapAttrs' (name: volume:
    lib.nameValuePair "root/${name}" {
      type = "zfs_fs";
      inherit (volume) mountpoint;
      options =
        {
          "com.sun:auto-snapshot" = lib.boolToString volume.autoSnapshot;
        }
        // lib.optionalAttrs (volume.quota != null) {
          inherit (volume) quota;
        };
    })
  cfg.volumes;
  datasets =
    {
      root =
        {
          type = "zfs_fs";
          mountpoint = "/";
          options."com.sun:auto-snapshot" = "false";
        }
        // lib.optionalAttrs cfg.impermanent {
          postMountHook = ''
            mkdir -p ${config.disko.rootMountPoint}/boot ${config.disko.rootMountPoint}/nix ${config.disko.rootMountPoint}/home ${config.disko.rootMountPoint}${cfg.persistPath}

            if ! zfs list -t snapshot -H -o name zroot/root@blank >/dev/null 2>&1; then
              zfs snapshot zroot/root@blank
            fi
          '';
        };
      "root/nix" = {
        type = "zfs_fs";
        mountpoint = "/nix";
      };
      "root/home" = {
        type = "zfs_fs";
        mountpoint = "/home";
        options."com.sun:auto-snapshot" = "true";
      };
      "root/persist" = {
        type = "zfs_fs";
        mountpoint = cfg.persistPath;
        options."com.sun:auto-snapshot" = "true";
      };
    }
    // homeDatasets // extraDatasets;
  mountpoints = lib.filter (mountpoint: lib.isString mountpoint && lib.hasPrefix "/" mountpoint) (
    lib.mapAttrsToList (_: dataset: dataset.mountpoint or null) datasets
  );
in {
  config = lib.mkIf enabled (lib.mkMerge [
    {
      boot = {
        supportedFilesystems = ["zfs"];
        zfs.forceImportRoot = false;
      };

      disko.zfs.enable = true;

      rootFs._diskoContent = {
        type = "zfs";
        pool = "zroot";
      };

      disko.devices.zpool.zroot = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = lib.mkForce {
          acltype = "posixacl";
          atime = "off";
          canmount = "off";
          compression = "zstd";
          dnodesize = "auto";
          mountpoint = "none";
          normalization = "formD";
          snapdir = "hidden";
          xattr = "sa";
        };
        inherit datasets;
      };

      fileSystems = lib.genAttrs mountpoints (_: {neededForBoot = true;});

      services.zfs = {
        autoSnapshot = {
          enable = true;
          frequent = 0;
        };
        autoScrub = {
          enable = true;
          pools = ["zroot"];
        };
      };

      boot.initrd.systemd.services.zfs-arc-limit = {
        description = "Limit ZFS ARC to ${toString cfg.zfs.arcMaxPercent}% of system memory";
        wantedBy = ["initrd.target"];
        after = ["systemd-modules-load.service"];
        before = ["zfs-import-zroot.service"];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
          read -r _ mem_kib _ </proc/meminfo
          printf '%s\n' "$((mem_kib * 1024 * ${toString cfg.zfs.arcMaxPercent} / 100))" > /sys/module/zfs/parameters/zfs_arc_max
        '';
      };
    }

    (lib.mkIf cfg.impermanent {
      boot.initrd.systemd.services.zfs-rollback-root = {
        description = "Reset impermanent root ZFS dataset to the blank boot snapshot";
        wantedBy = ["initrd.target"];
        after = ["zfs-import-zroot.service"];
        before = ["sysroot.mount"];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
          if zfs list -t snapshot -H -o name zroot/root@blank >/dev/null 2>&1; then
            echo "zfs-rollback-root: rolling back zroot/root@blank"
            zfs rollback -r zroot/root@blank
          else
            echo "zfs-rollback-root: WARNING snapshot zroot/root@blank not found; skipping rollback"
          fi
        '';
      };
    })
  ]);
}
