{lib, ...}: {
  home.stateVersion = "26.05";

  catppuccin = {
    enable = lib.mkDefault false;
  };

  programs.home-manager.enable = true;
}
