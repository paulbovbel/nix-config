{ config, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.devices = [ "nodev" ];

  networking.hostName = "pbovbel-dell";

  age.secrets.pbovbel-ssh-private-key = {
    file = ../../secrets/laptop/pbovbel-id_rsa.age;
    path = "/home/pbovbel/.ssh/id_rsa";
    owner = "pbovbel";
    group = "users";
    mode = "0400";
  };

  system.stateVersion = "25.05";
}
