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
  networking.networkmanager.enable = true;

  impermanenceRoot = {
    diskId = "/dev/disk/by-id/nvme-ADATA_SX8200PNP_2K4829A5C2U1";
    swapSize = "32G";
  };

  nvidia.sleep.enable = true;

  services.udev.extraRules = ''
    # Prevent the Audeze Maxwell dongle from autosuspending mid-session.
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="3329", ATTR{idProduct}=="4b19", TEST=="power/control", ATTR{power/control}="on"
  '';

  services.pipewire.wireplumber.extraConfig."51-hide-audio-devices" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "device.name" = "alsa_card.pci-0000_07_00.1";
          }
        ];
        actions.update-props."device.disabled" = true;
      }
      {
        matches = [
          {
            "device.name" = "alsa_card.pci-0000_09_00.4";
          }
        ];
        actions.update-props."device.profile" = "output:iec958-stereo";
      }
    ];
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
