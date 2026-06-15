{lib, ...}: {
  home.stateVersion = "26.05";

  catppuccin = {
    enable = lib.mkDefault false;
    autoEnable = lib.mkDefault false;
  };

  programs.home-manager.enable = true;
}
