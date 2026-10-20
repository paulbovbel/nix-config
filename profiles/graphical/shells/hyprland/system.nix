{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (builtins.elem "hyprland" (builtins.attrValues config.graphical.resolvedUserShells)) {
    programs.hyprland.enable = true;
    programs.ydotool.enable = true;
    users.users = lib.mapAttrs (_: _: {
      extraGroups = [config.programs.ydotool.group];
    }) (lib.filterAttrs (_: shell: shell == "hyprland") config.graphical.resolvedUserShells);
    security.pam.services.caelestia.fprintAuth = false;
    services.upower.enable = true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
    hardware.bluetooth.enable = true;
    environment.systemPackages = [pkgs.nautilus];
  };
}
