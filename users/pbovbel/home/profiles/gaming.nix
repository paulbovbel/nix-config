{ config, ... }:

{
  imports = [
    ./graphical.nix
  ];

  xdg.configFile."autostart/steam.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=Steam
    Exec=steam -silent
    X-GNOME-Autostart-enabled=true
  '';

  xdg.configFile."autostart/discord.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=Discord
    Exec=flatpak run com.discordapp.Discord
    X-GNOME-Autostart-enabled=true
  '';

  xdg.configFile."autostart/whatsapp.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=ZapZap
    Exec=flatpak run com.rtosta.zapzap
    X-GNOME-Autostart-enabled=true
  '';
}
