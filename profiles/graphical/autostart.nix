{
  file,
  name,
  exec,
}: {
  "autostart/${file}.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=${name}
    Exec=${exec}
    X-GNOME-Autostart-enabled=true
  '';
}
