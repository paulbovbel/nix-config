{lib, ...}: {
  imports = [
    ./graphical.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "code.desktop"
    "us.zoom.Zoom.desktop"
    "com.slack.Slack.desktop"
  ];

  xdg.configFile = {
    "autostart/slack.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Slack
      Exec=flatpak run com.slack.Slack
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/zoom.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Zoom
      Exec=flatpak run us.zoom.Zoom
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
