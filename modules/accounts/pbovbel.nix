{config, ...}: let
  keys = import ../keys.nix;
in {
  age.secrets.pbovbel-ssh-private-key = {
    file = ../secrets/common/pbovbel-id_rsa.age;
    path = "/home/pbovbel/.ssh/id_rsa";
    owner = "pbovbel";
    group = "users";
    mode = "0400";
    symlink = false;
  };

  systemd.tmpfiles.rules = [
    "d /home/pbovbel/.ssh 0700 pbovbel users - -"
  ];

  age.secrets.pbovbel-password-hash = {
    file = ../secrets/common/pbovbel-password-hash.age;
  };

  users.users.pbovbel = {
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.pbovbel-password-hash.path;
    description = "paul@bovbel.com";
    extraGroups = ["networkmanager" "wheel"];
    openssh.authorizedKeys.keys = [
      keys.pbovbel
    ];
  };
}
