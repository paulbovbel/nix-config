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
}
