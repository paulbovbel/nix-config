{
  config,
  lib,
  ...
}: let
  cfg = config.rootFs;
  volumeNames = lib.attrNames cfg.volumes;
  volumeMountpoints = map (volume: volume.mountpoint) (lib.attrValues cfg.volumes);
  reservedMountpoints = ["/" "/boot" "/home" "/nix" cfg.persistPath] ++ map (name: "/home/${name}") cfg.homeUsers;
in {
  imports = [
    ./options.nix
    ./disko.nix
    ./root-btrfs.nix
    ./root-zfs.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.diskId != null || cfg.existingPartitions != null;
        message = "rootFs requires either diskId or existingPartitions.";
      }
      {
        assertion = cfg.diskId == null || cfg.existingPartitions == null;
        message = "rootFs.diskId and rootFs.existingPartitions are mutually exclusive.";
      }
      {
        assertion = builtins.all (name: builtins.match "[A-Za-z0-9._-]+" name != null) volumeNames;
        message = "rootFs volume names may contain only letters, numbers, periods, underscores, and hyphens.";
      }
      {
        assertion = lib.length volumeMountpoints == lib.length (lib.unique volumeMountpoints);
        message = "rootFs volume mountpoints must be unique.";
      }
      {
        assertion = lib.intersectLists reservedMountpoints volumeMountpoints == [];
        message = "rootFs volumes may not replace built-in root filesystem mountpoints.";
      }
    ];

    boot.initrd.luks.devices.crypted = lib.mkIf cfg.encrypted {
      crypttabExtraOpts = ["tpm2-device=auto"];
    };

    environment.persistence.${cfg.persistPath} = lib.mkIf cfg.impermanent {
      hideMounts = true;
      directories = lib.unique cfg.persistDirectories;
      files = lib.unique cfg.persistFiles;
    };
  };
}
