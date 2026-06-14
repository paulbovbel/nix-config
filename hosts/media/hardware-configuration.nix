{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "sd_mod"];
      kernelModules = [];
      systemd.enable = true;
      luks.devices."crypted" = {
        crypttabExtraOpts = ["tpm2-device=auto"];
      };
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
    supportedFilesystems = ["zfs"];
    zfs.forceImportRoot = false;
  };

  networking = {
    useDHCP = false;
    bonds.bond0 = {
      interfaces = ["eno1" "eno2"];
      driverOptions.mode = "balance-rr";
    };
    interfaces = {
      eno1.useDHCP = false;
      eno2.useDHCP = false;
      bond0.useDHCP = true;
    };
  };

  impermanenceRoot.diskId = "/dev/disk/by-id/nvme-PC401_NVMe_SK_hynix_1TB_EJ86N780110506T42";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
