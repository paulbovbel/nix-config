{
  lib,
  config,
  ...
}: let
  cfg = config.impermanenceRoot;
in {
  options.impermanenceRoot = {
    diskId = lib.mkOption {
      type = lib.types.str;
      description = "Disk id path for main system disk (e.g. /dev/disk/by-id/...)";
    };

    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "32G";
      description = "Swap partition size for disko layout.";
    };
  };

  config.disko.devices = {
    disk.main = {
      type = "disk";
      device = cfg.diskId;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          swap = {
            size = cfg.swapSize;
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };
          encrypted = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings.allowDiscards = true;
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };

    zpool.zroot = {
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
        xattr = "sa";
      };

      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          options."com.sun:auto-snapshot" = "false";
          postCreateHook = ''
            if ! zfs list -t snapshot -H -o name ${cfg.rootDataset}@${cfg.blankSnapshot} >/dev/null 2>&1; then
              zfs snapshot ${cfg.rootDataset}@${cfg.blankSnapshot}
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
      };
    };
  };
}
