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
    };
    # The ASPEED BMC VGA adapter reports a corrupt EDID and floods the journal.
    blacklistedKernelModules = ["ast"];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
  };

  rootFs.diskId = "/dev/disk/by-id/nvme-PC401_NVMe_SK_hynix_1TB_EJ86N780110506T42";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
