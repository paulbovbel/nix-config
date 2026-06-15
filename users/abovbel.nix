{config, ...}: {
  age.secrets.abovbel-password-hash = {
    file = ../secrets/common/abovbel-password-hash.age;
  };

  users.users.abovbel = {
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.abovbel-password-hash.path;
    description = "arthur@bovbel.com";
    extraGroups = ["networkmanager"];
  };

  disko.devices.zpool.zroot.datasets."root/home/abovbel" = {
    type = "zfs_fs";
    mountpoint = "/home/abovbel";
  };
}
