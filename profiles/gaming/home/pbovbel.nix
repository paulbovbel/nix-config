{
  config,
  lib,
  ...
}: let
  mkAutostart = import ../../graphical/autostart.nix;
  workActive = builtins.elem "work" config.profiles.selected;
in {
  imports = [
    ../../graphical/home/pbovbel.nix
    ../home.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkIf (!workActive) (lib.mkAfter [
    "steam.desktop"
    "com.discordapp.Discord.desktop"
  ]);

  xdg.configFile = lib.mkIf (!workActive) (lib.mkMerge (map mkAutostart [
    {
      file = "discord";
      name = "Discord";
      exec = "flatpak run com.discordapp.Discord";
    }
  ]));
}
