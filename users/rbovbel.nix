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

  disko.zfs.settings.datasets."zroot/root/home/rbovbel" = {
    properties.mountpoint = "/home/rbovbel";
  };
}
