{
  lib,
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

  bovbel.background = {
    enable = true;
    source = ../../../assets/wallpapers/pbovbel-frehj36ltk101.png;
    fileName = "pbovbel-frehj36ltk101.png";
    lockscreenSource = ../../../assets/wallpapers/pbovbel-tropicanair.jpg;
    lockscreenFileName = "pbovbel-tropicanair.jpg";
  };

  dconf.settings = {
    "org/gnome/shell" = {
      favorite-apps = lib.mkAfter [
        "com.rtosta.zapzap.desktop"
        "kitty.desktop"
        "code.desktop"
      ];
    };
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

  xdg.configFile = lib.mkMerge (map mkAutostart [
    {
      file = "solaar";
      name = "Solaar";
      exec = "${pkgs.solaar}/bin/solaar --window=hide";
    }
    {
      file = "whatsapp";
      name = "ZapZap";
      exec = "flatpak run com.rtosta.zapzap";
    }
  ]);
}
