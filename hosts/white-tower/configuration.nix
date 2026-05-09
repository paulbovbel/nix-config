{ config, lib, pkgs, unstablePkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  # boot.kernelPackages = unstablePkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    # package = unstablePkgs.linuxPackages_latest.nvidiaPackages.latest;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
  };

  boot.extraModprobeConfig = ''
    options nvidia NVreg_PreserveVideoMemoryAllocations=1
    options nvidia NVreg_TemporaryFilePath=/var/tmp
  '';

  boot.kernelParams = [
    # Prefer deep suspend (S3) over s2idle when available.
    "mem_sleep_default=deep"
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];

  systemd.tmpfiles.rules = [
    "d /var/tmp 1777 root root -"
  ];

  # something on this host does spuriously wake it up from suspend, so disable all wake sources except power buttons for now
  systemd.services.disable-wake-sources = {
    description = "Disable wake sources except power buttons";
    wantedBy = [ "multi-user.target" "sleep.target" ];
    before = [ "sleep.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      if [ -r /proc/acpi/wakeup ]; then
        while read -r dev _ state _; do
          if [ "''${state}" = "*enabled" ] && [ "''${dev}" != "PWRB" ] && [ "''${dev}" != "PWRF" ]; then
            echo "''${dev}" > /proc/acpi/wakeup
          fi
        done < /proc/acpi/wakeup
      fi
      for wakeup in /sys/class/wakeup/*/device/power/wakeup; do
        [ -e "''${wakeup}" ] || continue
        case "''${wakeup}" in
          */PWRB/*|*/PWRF/*) ;;
          *) echo disabled > "''${wakeup}" ;;
        esac
      done
    '';
  };

  systemd.services.nvidia-suspend.enable = true;
  systemd.services.nvidia-resume.enable = true;
  systemd.services.nvidia-hibernate.enable = true;

  networking.hostName = "white-tower";
  networking.networkmanager.enable = true;

  system.stateVersion = "25.05";
}
