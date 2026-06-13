{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking.hostName = "white-tower";

  networking.interfaces.enp6s0.wakeOnLan = {
    enable = true;
<<<<<<< HEAD
    policy = ["magic"];
=======
    policy = "magic";
>>>>>>> 21ade6a (Simplify nvidia module, deal with suspend issues in white-tower host config)
  };

  impermanenceRoot = {
    diskId = "/dev/disk/by-id/nvme-ADATA_SX8200PNP_2K4829A5C2U1";
    swapSize = "32G";
  };

  services.udev.extraRules = ''
    # Prevent the Audeze Maxwell dongle from autosuspending mid-session.
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="3329", ATTR{idProduct}=="4b19", TEST=="power/control", ATTR{power/control}="on"
  '';

  systemd.services.disable-wake-sources = {
    description = "Disable wake sources except power buttons";
    # Apply at boot and before sleep to avoid flaky spontaneous wakeups.
    wantedBy = ["multi-user.target" "sleep.target"];
    before = ["sleep.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      for wakeup in /sys/class/wakeup/*/device/power/wakeup; do
        [ -e "$wakeup" ] || continue
        source="''${wakeup#/sys/class/wakeup/}"
        source="''${source%%/*}"
        case "$source" in
        PWRB | PWRF) ;;
        *)
          if [ ! -d "/sys/class/wakeup/$source/device/net" ]; then
            printf 'disabled\n' >"$wakeup"
          fi
          ;;
        esac
      done
    '';
  };

  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "610.43.02";
    sha256_64bit = "sha256-MDSgVLtM33dS/43CclZMsQVROAS/9TU4lFkBsWyndGM=";
    openSha256 = "sha256-hP5NVZZ4vGsACHLmUDKq4uckpd/kn1GxCSYnnJfAuBs=";
    settingsSha256 = "sha256-0YAhufRgjDW+uR+kjaTb154fibpcDw8QowfrucoZsKE=";
    persistencedSha256 = "sha256-Whgv9X+v2fRhzliOl2LzltY9v1SxDafFfv3IUPqj/hk=";
  };

  system.stateVersion = "26.05";
}
