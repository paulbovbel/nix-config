{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./base.nix
    ../common/graphical.nix
    ../common/vscode.nix
    ../common/avatar.nix
  ];

  home.file = {
    ".local/share/backgrounds/pbovbel-tropicanair.jpg".source =
      ../../assets/wallpapers/pbovbel-tropicanair.jpg;
  };
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

  bovbel.avatar = {
    enable = true;
    source = ../../assets/avatars/pbovbel.png;
    fileName = "pbovbel-avatar.png";
  };

  home.packages = [
    pkgs.libsecret
    pkgs.nixfmt
    pkgs.python3
    pkgs.uv
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
  };
}
