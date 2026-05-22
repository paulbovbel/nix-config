{ config, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.devices = [ "nodev" ];

  networking.hostName = "pbovbel-dell";

  system.stateVersion = "25.05";
}
