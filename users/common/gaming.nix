{
  config,
  lib,
  ...
}: {
  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "steam.desktop"
    "com.discordapp.Discord.desktop"
  ];

  xdg.configFile."autostart/steam.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=Steam
    Exec=steam -silent
    Icon=steam
    X-GNOME-Autostart-enabled=true
  '';

  home.activation.steamappsLibrary = lib.hm.dag.entryAfter ["writeBoundary"] ''
    steamapps_path="${config.xdg.dataHome}/Steam/steamapps"
    steamapps_target="/steam-library/${config.home.username}"

    mkdir -p "$steamapps_target"
    mkdir -p "$(dirname "$steamapps_path")"

    if [ ! -L "$steamapps_path" ] || [ "$(readlink "$steamapps_path")" != "$steamapps_target" ]; then
      rm -rf "$steamapps_path"
      ln -s "$steamapps_target" "$steamapps_path"
    fi
  '';
}
