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
      systemd.enable = true;
    };
    kernelModules = ["kvm-amd"];
    extraModulePackages = [];
    supportedFilesystems = ["zfs"];
    zfs.forceImportRoot = false;
  };

  networking.interfaces.enp6s0.wakeOnLan = {
    enable = true;
    policy = ["magic"];
  };

  rootZfs.diskId = "/dev/disk/by-id/nvme-PM9A1_NVMe_Samsung_512GB__S6H3NX0RC78893";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
