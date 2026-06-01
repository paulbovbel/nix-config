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
      luks.devices."crypted" = {
        crypttabExtraOpts = ["tpm2-device=auto"];
      };
    };
    kernelModules = ["kvm-amd"];
    extraModulePackages = [];
    supportedFilesystems = ["zfs"];
    zfs.forceImportRoot = false;
  };

  networking.hostId = "3f0c8d5a";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
