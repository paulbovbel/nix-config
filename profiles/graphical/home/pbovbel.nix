{
  config,
  pkgs,
  ...
}: let
  mkAutostart = import ../autostart.nix;
in {
  imports = [
    ../../common/home/pbovbel.nix
    ../home.nix
    ../vscode.nix
    ../avatar.nix
  ];

  home.file = {
    ".local/share/backgrounds/pbovbel-tropicanair.jpg".source =
      ../../../assets/wallpapers/pbovbel-tropicanair.jpg;
  };
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file://${config.home.homeDirectory}/.local/share/backgrounds/pbovbel-tropicanair.jpg";
      picture-uri-dark = "file://${config.home.homeDirectory}/.local/share/backgrounds/pbovbel-tropicanair.jpg";
      picture-options = "zoom";
    };
    "org/gnome/shell".favorite-apps = [
      "org.mozilla.firefox.desktop"
      "org.gnome.Nautilus.desktop"
      "com.rtosta.zapzap.desktop"
      "kitty.desktop"
      "code.desktop"
    ];
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 900;
      sleep-inactive-battery-timeout = 900;
    };
  };

  bovbel.avatar = {
    enable = true;
    source = ../../../assets/avatars/pbovbel.png;
    fileName = "pbovbel-avatar.png";
  };

  programs.vscode.profiles.default.userSettings = builtins.fromJSON (
    builtins.readFile ./vscode-settings.json
  );

  home.packages = [
    pkgs.libsecret
    pkgs.nixfmt
    pkgs.python3
    pkgs.uv
  ];

  xdg.configFile = mkAutostart {
    file = "solaar";
    name = "Solaar";
    exec = "${pkgs.solaar}/bin/solaar --window=hide";
  };
}
