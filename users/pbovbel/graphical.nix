{config, ...}: {
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
}
