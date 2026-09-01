{
  config,
  lib,
  ...
}: let
  cfg = config.rootFs;
  rootContent =
    if cfg.encrypted
    then {
      type = "luks";
      name = "crypted";
      settings.allowDiscards = true;
      content = cfg._diskoContent;
    }
    else cfg._diskoContent;
in {
  config = lib.mkIf cfg.enable {
    disko.devices.disk =
      if cfg.existingPartitions != null
      then
        {
          esp = {
            type = "disk";
            device = cfg.existingPartitions.efiDevice;
            destroy = false;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          root = {
            type = "disk";
            device = cfg.existingPartitions.rootDevice;
            content = rootContent;
          };
        }
        // lib.optionalAttrs (cfg.existingPartitions.swapDevice != null) {
          swap = {
            type = "disk";
            device = cfg.existingPartitions.swapDevice;
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };
        }
      else {
        main = {
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
              ${
                if cfg.encrypted
                then "encrypted"
                else "root"
              } = {
                size = "100%";
                content = rootContent;
              };
            };
          };
        };
      };
  };
}
