{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  cfg = config.rootFs;
  enabled = cfg.enable && cfg.backend == "btrfs";
  mountOptions = ["compress=zstd" "noatime" "discard=async"];
  btrfsContent =
    {
      type = "btrfs";
      extraArgs = ["-f"];
      inherit subvolumes;
    }
    // lib.optionalAttrs cfg.impermanent {
      postCreateHook = ''
        mountpoint=$(mktemp -d)
        mount "$device" "$mountpoint" -o subvolid=5
        trap 'umount "$mountpoint"; rmdir "$mountpoint"' EXIT

        mkdir -p "$mountpoint/@root/boot" "$mountpoint/@root/nix" "$mountpoint/@root/home" "$mountpoint/@root${cfg.persistPath}" "$mountpoint/@root/.btrfs-root"
        if ! btrfs subvolume show "$mountpoint/@root-blank" >/dev/null 2>&1; then
          btrfs subvolume snapshot -r "$mountpoint/@root" "$mountpoint/@root-blank"
        fi
      '';
    };
  homeSubvolumes = lib.listToAttrs (map (name: {
      name = "@home-${name}";
      value = {
        mountpoint = "/home/${name}";
        inherit mountOptions;
      };
    })
    cfg.homeUsers);
  extraSubvolumes = lib.mapAttrs' (name: volume:
    lib.nameValuePair "@volume-${name}" {
      inherit (volume) mountpoint;
      inherit mountOptions;
    })
  cfg.volumes;
  subvolumes =
    {
      "@root" = {
        mountpoint = "/";
        inherit mountOptions;
      };
      "@nix" = {
        mountpoint = "/nix";
        inherit mountOptions;
      };
      "@home" = {
        mountpoint = "/home";
        inherit mountOptions;
      };
      "@persist" = {
        mountpoint = cfg.persistPath;
        inherit mountOptions;
      };
      "@snapshots" = {};
    }
    // homeSubvolumes // extraSubvolumes;
  mountpoints = lib.filter (mountpoint: mountpoint != null) (lib.mapAttrsToList (_: subvolume: subvolume.mountpoint or null) subvolumes);
  snapshotSubvolumes =
    {
      "@home".snapshot_create = "onchange";
      "@persist".snapshot_create = "onchange";
    }
    // lib.listToAttrs (map (name: {
        name = "@home-${name}";
        value.snapshot_create = "onchange";
      })
      cfg.homeUsers)
    // lib.mapAttrs' (name: _:
      lib.nameValuePair "@volume-${name}" {snapshot_create = "onchange";})
    (lib.filterAttrs (_: volume: volume.autoSnapshot) cfg.volumes);
  quotaVolumes = lib.filterAttrs (_: volume: volume.quota != null) cfg.volumes;
  btrfsDevice = config.fileSystems."/".device;
  deviceUnit = "${utils.escapeSystemdPath btrfsDevice}.device";
in {
  config = lib.mkIf enabled (lib.mkMerge [
    {
      boot.supportedFilesystems = ["btrfs"];

      rootFs._diskoContent = btrfsContent;

      fileSystems =
        lib.genAttrs mountpoints (_: {neededForBoot = true;})
        // {
          "/.btrfs-root" = {
            device = btrfsDevice;
            fsType = "btrfs";
            options = mountOptions ++ ["subvolid=5"];
            neededForBoot = true;
          };
        };

      services.btrfs.autoScrub = {
        enable = true;
        interval = "monthly";
        fileSystems = ["/"];
      };

      services.btrbk.instances.root-fs = {
        onCalendar = "hourly";
        snapshotOnly = true;
        settings = {
          timestamp_format = "long-iso";
          snapshot_dir = "@snapshots";
          snapshot_preserve_min = "latest";
          snapshot_preserve = "24h 7d 4w 12m";
          snapshot_qgroup_destroy = "yes";
          volume."/.btrfs-root".subvolume = snapshotSubvolumes;
        };
      };

      systemd.services.btrbk-root-fs.unitConfig.RequiresMountsFor = ["/.btrfs-root"];
    }

    (lib.mkIf cfg.impermanent {
      boot.initrd.systemd.services.btrfs-reset-root = {
        description = "Reset the impermanent Btrfs root subvolume";
        wantedBy = ["initrd.target"];
        requires = [deviceUnit];
        after = [deviceUnit];
        before = ["sysroot.mount"];
        unitConfig.DefaultDependencies = false;
        path = [pkgs.btrfs-progs pkgs.coreutils pkgs.util-linux];
        serviceConfig.Type = "oneshot";
        script = ''
          pool_mount=/run/btrfs-root
          cleanup() {
            umount "$pool_mount" 2>/dev/null || true
            rmdir "$pool_mount" 2>/dev/null || true
          }
          trap cleanup EXIT

          mkdir -p "$pool_mount"
          mount -o subvolid=5 ${lib.escapeShellArg btrfsDevice} "$pool_mount"

          delete_subvolume_recursively() {
            while IFS= read -r child; do
              delete_subvolume_recursively "$pool_mount/''${child#* path }"
            done < <(btrfs subvolume list -o "$1")
            btrfs subvolume delete "$1"
          }

          if btrfs subvolume show "$pool_mount/@root" >/dev/null 2>&1; then
            delete_subvolume_recursively "$pool_mount/@root"
          fi
          if ! btrfs subvolume show "$pool_mount/@root-blank" >/dev/null 2>&1; then
            printf '%s\n' 'btrfs-reset-root: @root-blank is missing' >&2
            exit 1
          fi
          btrfs subvolume snapshot "$pool_mount/@root-blank" "$pool_mount/@root"

          cleanup
          trap - EXIT
        '';
      };
    })

    (lib.mkIf (quotaVolumes != {}) {
      systemd.services.root-fs-btrfs-quotas = {
        description = "Apply root Btrfs subvolume quotas";
        wantedBy = ["local-fs.target"];
        before = ["local-fs.target"];
        unitConfig.RequiresMountsFor = map (volume: volume.mountpoint) (lib.attrValues quotaVolumes);
        path = [pkgs.btrfs-progs];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          btrfs quota enable /.btrfs-root
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: volume: "btrfs qgroup limit ${lib.escapeShellArg volume.quota} ${lib.escapeShellArg volume.mountpoint}") quotaVolumes)}
        '';
      };
    })
  ]);
}
