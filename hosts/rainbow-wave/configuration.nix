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
  };

  networking = {
    hostName = "rainbow-wave";
    hostId = "4619f943";
    interfaces.enp6s0.wakeOnLan = {
      enable = true;
      policy = ["magic"];
    };
  };

  rootFs = {
    enable = true;
    backend = "zfs";
    impermanent = true;
    swapSize = "8G";
  };

  autoUpgrade.enable = true;

  gameStreaming = {
    enable = true;
    encoder = "nvenc";
  };
  services.sunshine.settings = {
    nvenc_preset = 5;
    nvenc_twopass = "quarter_res";
    nvenc_spatial_aq = "enabled";
    nvenc_vbv_increase = 200;
  };
  programs.gamemode.settings.gpu = {
    apply_gpu_optimisations = "accept-responsibility";
    gpu_device = 0;
    nv_powermizer_mode = 1;
  };

  system.stateVersion = "26.05";

  netboot = {
    enable = true;
    installLegacyImage = true;
  };
}
