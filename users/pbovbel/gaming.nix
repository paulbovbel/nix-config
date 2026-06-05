_: {
  imports = [
    ./graphical.nix
    ../common/gaming.nix
  ];

  xdg.configFile = {
    "autostart/discord.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Discord
      Exec=flatpak run com.discordapp.Discord
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/whatsapp.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=ZapZap
      Exec=flatpak run com.rtosta.zapzap
      X-GNOME-Autostart-enabled=true
    '';
  };
}
