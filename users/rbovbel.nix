{config, ...}: {
  age.secrets.rbovbel-password-hash = {
    file = ../secrets/common/rbovbel-password-hash.age;
  };

  users.users.rbovbel = {
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.rbovbel-password-hash.path;
    description = "rebecca@bovbel.com";
    extraGroups = ["networkmanager"];
  };

  disko.devices.zpool.zroot.datasets."root/home/rbovbel" = {
    type = "zfs_fs";
    mountpoint = "/home/rbovbel";
  };
}
