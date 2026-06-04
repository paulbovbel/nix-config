{lib, ...}: {
  imports = [
    ./graphical.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "steam.desktop"
    "com.discordapp.Discord.desktop"
  ];

  xdg.configFile = {
    "autostart/steam.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Steam
      Exec=steam -silent
      Icon=steam
      X-GNOME-Autostart-enabled=true
    '';
  };
}
