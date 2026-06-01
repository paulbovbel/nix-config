{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./base.nix
    ../common/graphical.nix
    ../common/gravatar.nix
  ];

  home.file.".local/share/backgrounds/pbovbel-tropicanair.jpg".source =
    ../../assets/wallpapers/pbovbel-tropicanair.jpg;
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file://${config.home.homeDirectory}/.local/share/backgrounds/pbovbel-tropicanair.jpg";
      picture-uri-dark = "file://${config.home.homeDirectory}/.local/share/backgrounds/pbovbel-tropicanair.jpg";
      picture-options = "zoom";
    };
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 900;
      sleep-inactive-battery-timeout = 900;
    };
  };

  bovbel.gravatarAvatar = {
    enable = true;
    hash = "c436d411a0ecc119476d704396a47d3e";
    fileName = "pbovbel-gravatar.jpg";
  };

  home.packages = [
    pkgs.tail-tray
  ];

  xdg.configFile = {
    "autostart/solaar.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Solaar
      Exec=${pkgs.solaar}/bin/solaar --window=hide
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/tail-tray.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Tail Tray
      Exec=${pkgs.tail-tray}/bin/tail-tray
      X-GNOME-Autostart-enabled=true
    '';
  };
}
