{...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.devices = ["nodev"];

  networking.hostName = "media";

  system.stateVersion = "26.05";
}
