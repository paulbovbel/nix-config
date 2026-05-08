{ unstablePkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  boot.kernelPackages = unstablePkgs.linuxPackages_latest;

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = unstablePkgs.linuxPackages_latest.nvidiaPackages.latest;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
  };

  boot.extraModprobeConfig = ''
    options nvidia NVreg_PreserveVideoMemoryAllocations=1
    options nvidia NVreg_TemporaryFilePath=/var/tmp
  '';

  boot.kernelParams = [ "mem_sleep_default=deep" ];

  systemd.tmpfiles.rules = [
    "d /var/tmp 1777 root root -"
  ];

  systemd.services.nvidia-suspend.enable = true;
  systemd.services.nvidia-resume.enable = true;
  systemd.services.nvidia-hibernate.enable = true;

  networking.hostName = "white-tower";
  networking.networkmanager.enable = true;

  system.stateVersion = "25.11";
}
