{lib, ...}: let
  mkAutostart = import ../../graphical/autostart.nix;
in {
  imports = [
    ../../graphical/home/pbovbel.nix
    ../home.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "steam.desktop"
    "com.discordapp.Discord.desktop"
  ];

  xdg.configFile = lib.mkMerge (map mkAutostart [
    {
      file = "discord";
      name = "Discord";
      exec = "flatpak run com.discordapp.Discord";
    }
  ]);
}
