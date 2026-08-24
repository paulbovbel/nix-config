{lib, ...}: let
  mkAutostart = import ../autostart.nix;
in {
  imports = [
    ../../common/home/rbovbel.nix
    ../home.nix
    ../avatar.nix
  ];

  bovbel.background = {
    enable = true;
    source = ../../../assets/wallpapers/pbovbel-tropicanair.jpg;
    fileName = "rbovbel-tropicanair.jpg";
  };

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "com.rtosta.zapzap.desktop"
    "kitty.desktop"
  ];

  bovbel.avatar = {
    enable = true;
    source = ../../../assets/avatars/rbovbel.png;
    fileName = "rbovbel-avatar.png";
  };

  xdg.configFile = mkAutostart {
    file = "whatsapp";
    name = "ZapZap";
    exec = "flatpak run com.rtosta.zapzap";
  };
}
