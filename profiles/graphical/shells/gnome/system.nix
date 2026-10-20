{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (builtins.elem "gnome" (builtins.attrValues config.graphical.resolvedUserShells)) {
    services = {
      desktopManager.gnome.enable = true;
      gnome.gnome-remote-desktop.enable = true;
    };

    environment.systemPackages = [
      pkgs.gnome-icon-theme
      pkgs.gnome-power-manager
      pkgs.gnome-tweaks
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.dash-to-dock
      pkgs.gnomeExtensions.headsetcontrol
      pkgs.gnomeExtensions.unlock-dialog-background
      pkgs.yaru-theme
    ];
  };
}
