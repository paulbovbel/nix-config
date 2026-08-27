{pkgs, ...}: {
  imports = [
    ../site.nix
    ./hardware-configuration.nix
  ];

  boot = {
    initrd.systemd.enable = true;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # TODO try CachyOS kernel for gaming performance?
    kernelPackages = pkgs.linuxPackages;
    zfs.forceImportRoot = false;
  };

  networking = {
    hostName = "white-tower";
    hostId = "3f0c8d5a";
    interfaces.enp6s0.wakeOnLan = {
      enable = true;
      policy = ["magic"];
    };
  };

  rootZfs = {
    enable = true;
    impermanent = true;
    swapSize = "32G";
  };

  llamaCpp.enable = false;

  services.udev.extraRules = ''
    # Prevent the Audeze Maxwell dongle from autosuspending mid-session.
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="3329", ATTR{idProduct}=="4b19", TEST=="power/control", ATTR{power/control}="on"
  '';

  systemd.services.disable-wake-sources = {
    description = "Disable ACPI wake sources except physical power buttons";
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

  system.stateVersion = "26.05";

  netboot = {
    enable = true;
    installLegacyImage = true;
  };
}
