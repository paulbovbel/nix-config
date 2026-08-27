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
      availableKernelModules = ["nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod"];
      kernelModules = [];
    };
    kernelModules = ["kvm-amd"];
    extraModulePackages = [];
    supportedFilesystems = ["zfs"];
  };

  nvidia.enable = true;

  rootZfs.diskId = "/dev/disk/by-id/nvme-ADATA_SX8200PNP_2K4829A5C2U1";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
