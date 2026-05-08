{ config, ... }:

{
  imports = [
  ];

  networking.hostName = "pbovbel-dell";

  age.secrets.pbovbel-ssh-private-key = {
    file = ../../secrets/shared/pbovbel-id_rsa.age;
    path = "/home/pbovbel/.ssh/id_rsa";
    owner = "pbovbel";
    group = "users";
    mode = "0400";
  };

  system.stateVersion = "25.11";
}
